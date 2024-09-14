# Rockstor Bareos server set
FROM opensuse/leap:15.6

# https://specs.opencontainers.org/image-spec/annotations/
LABEL maintainer="The Rockstor Project <https://rockstor.com>"
LABEL org.opencontainers.image.authors="The Rockstor Project <https://rockstor.com>"
LABEL org.opencontainers.image.description="Bareos Director - deploys packages from https://download.bareos.org/"

# We only know if we are COMMUNIT or SUBSCRIPTION at run-time via env vars.
# 'postgresql' utility and client programs 10MB
RUN zypper --non-interactive install wget iputils postgresql

# Config (all Baros deamons):
VOLUME /etc/bareos
# Data/status (woking directory)
# Also default DB dump/backup file (bareos.sql) location (see FileSet 'Catalog')
VOLUME /var/lib/bareos

# 'Director' communications port.
EXPOSE 9101

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

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

# BareOS services hav e WorkingDirectory=/var/lib/bareos
# /etc/systemd/system/bareos-director.service

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir -f"]
