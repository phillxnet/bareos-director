# Rockstor Bareos server set
FROM opensuse/leap:15.6

# For our setup we explicitly use container's root user at '/':
USER root
WORKDIR /

# https://specs.opencontainers.org/image-spec/annotations/
LABEL maintainer="The Rockstor Project <https://rockstor.com>"
LABEL org.opencontainers.image.authors="The Rockstor Project <https://rockstor.com>"
LABEL org.opencontainers.image.description="Bareos Director - deploys packages from https://download.bareos.org/"

# We only know if we are COMMUNIT or SUBSCRIPTION at run-time via env vars.
# 'postgresql' utility and client programs 10MB
RUN zypper --non-interactive install tar gzip wget iputils strace postgresql

# Create bareos group & user within container with set gid & uid.
# Docker host and docker container share uid & gid.
# Pre-empting the bareos packages' installer doing the same, as we need to known gid & uid for host volume permissions.
# We leave bareos home-dir to be created by the package install scriptlets.
RUN groupadd --system --gid 105 bareos
RUN useradd --system --uid 105 --comment "bareos" --home-dir /var/lib/bareos -g bareos -G disk,tape --shell /bin/false bareos

RUN <<EOF
# https://docs.bareos.org/IntroductionAndTutorial/InstallingBareos.html#install-on-suse-based-linux-distributions

# ADD REPOS (COMMUNITY OR SUBSCRIPTION)
# https://docs.bareos.org/IntroductionAndTutorial/WhatIsBareos.html#bareos-binary-release-policy
# - Empty/Undefined BAREOS_SUB_USER & BAREOS_SUB_PASS = COMMUNITY 'current' repo.
# -- Community current repo: https://download.bareos.org/current
# -- wget https://download.bareos.org/current/SUSE_15/add_bareos_repositories.sh
# - BAREOS_SUB_USER & BAREOS_SUB_PASS = Subscription rep credentials
# -- Subscription repo: https://download.bareos.com/bareos/release/
# User + Pass entered in the following retrieves the script pre-edited:
# wget https://download.bareos.com/bareos/release/23/SUSE_15/add_bareos_repositories.sh
# or
# wget https://download.bareos.com/bareos/release/23/SUSE_15/add_bareos_repositories_template.sh
# sed edit using BAREOS_SUB_USER & BAREOS_SUB_PASS
if [ ! -f  /etc/bareos/bareos-director-install.control ]; then
  # Retrieve and Run Bareos's official repository config script
  wget https://download.bareos.org/current/SUSE_15/add_bareos_repositories.sh
  sh ./add_bareos_repositories.sh
  zypper --non-interactive --gpg-auto-import-keys refresh
  # Director daemon & bconsole cli client
  zypper --non-interactive install bareos-director bareos-bconsole
  # Control file
  touch /etc/bareos/bareos-director-install.control
fi
EOF

# Stash default package config: ready to populare host volume mapping
# https://docs.bareos.org/Configuration/CustomizingTheConfiguration.html#subdirectory-configuration-scheme
RUN ls -la /etc/bareos > /etc/bareos/bareos-dir.d/package-default-permissions.txt
RUN tar czf bareos-dir-d.tgz /etc/bareos/bareos-dir.d
RUN tar czf bareos-dir-export.tgz /etc/bareos/bareos-dir-export
RUN cp -a /etc/bareos/bconsole.conf /bconsole.conf-default

# Director WebUI Console template
# https://docs.bareos.org/IntroductionAndTutorial/BareosWebui.html#create-a-restricted-consoles
# - https://raw.githubusercontent.com/bareos/bareos/master/webui/install/bareos/bareos-dir.d/console/admin.conf.example
# - https://raw.githubusercontent.com/bareos/bareos/master/webui/install/bareos/bareos-dir.d/profile/webui-admin.conf
# bareos-webui installs:
# - /etc/bareos/bareos-dir.d/console/admin.conf.example # console file
# - /etc/bareos/bareos-dir.d/profile/webui-admin.conf # profile file
# We put copies in container root.
COPY admin.conf.example /admin.conf.example
COPY webui-admin.conf /webui-admin.conf

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

# BareOS services have WorkingDirectory=/var/lib/bareos
# https://docs.docker.com/reference/dockerfile/#workdir
WORKDIR /var/lib/bareos

# Config (all Baros deamons):
VOLUME /etc/bareos
# Data/status (woking directory)
# Also default DB dump/backup file (bareos.sql) location (see FileSet 'Catalog')
VOLUME /var/lib/bareos

# 'Director' communications port.
EXPOSE 9101

# See README.md 'Host User configuration' section.
USER bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir",  "--foreground", "--debug-level", "1"]
