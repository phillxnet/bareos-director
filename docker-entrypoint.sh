#!/usr/bin/sh

if [ ! -f /etc/bareos/bareos-director-config.control ]; then
  # Populate host volume map with package defaults from docker build steps:
  tar xfz /bareos-dir-d.tgz --backup=simple --suffix=.before-director-config --strip 2 --directory /etc/bareos
  tar xfz /bareos-dir-export.tgz --backup=simple --suffix=.before-director-config --strip 2 --directory /etc/bareos
  # Credentials for default 'MyCatalog'
  sed -i 's#dbname = .*#dbname = '\""${DB_NAME}"\"'#' \
    /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
  sed -i 's#dbuser = .*#dbuser = '\""${DB_USER}"\"'#' \
    /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
  sed -i 's#dbpassword = .*#dbpassword = '\""${DB_PASSWORD}"\"'#' \
    /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
  # Director 'Storage' host/pass (Default Name File, Device = FileStorage)
  sed -i 's#Address = .*#Address = '\""${BAREOS_SD_HOST}"\"'#' \
    /etc/bareos/bareos-dir.d/storage/File.conf
  sed -i 's#Password = .*#Password = '\""${BAREOS_SD_PASSWORD}"\"'#' \
    /etc/bareos/bareos-dir.d/storage/File.conf
  # Director 'Client' host/pass (default Name bareos-fd)
  sed -i 's#Address = .*#Address = '\""${BAREOS_FD_HOST}"\"'#' \
    /etc/bareos/bareos-dir.d/client/bareos-fd.conf
  sed -i 's#Password = .*#Password = '\""${BAREOS_FD_PASSWORD}"\"'#' \
    /etc/bareos/bareos-dir.d/client/bareos-fd.conf
  # Director WebUI Console file from template: password edited:
  sed 's#Password = .*#Password = '\""${BAREOS_WEBUI_PASSWORD}"\"'#' \
    /admin.conf.example > /etc/bareos/bareos-dir.d/console/admin.conf
  # Director WebUI profile file copied as-is:
  cp /webui-admin.conf /etc/bareos/bareos-dir.d/profile/

  # Add pgpass file to ${DB_USER} home
  # https://docs.bareos.org/TasksAndConcepts/CatalogMaintenance.html#remote-postgresql-database
  # "/var/lib/bareos" for "bareos" user.
  homedir=$(getent passwd "$DB_USER" | cut -d: -f6)
  echo "${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASSWORD}" > "${homedir}/.pgpass"
  chmod 600 "${homedir}/.pgpass"
  chown "${DB_USER}" "${homedir}/.pgpass"

  # Control file
  touch /etc/bareos/bareos-director-config.control
fi

if [ ! -f /etc/bareos/bareos-bconsole-config.control ]; then
  sed 's#Password = .*#Password = '\""${BAREOS_BCONSOLE_PASSWORD}"\"'#' \
    /bconsole.conf-default > /etc/bareos/bconsole.conf
  chmod 640 /etc/bareos/bconsole.conf
  touch /etc/bareos/bareos-bconsole-config.control
fi

if [ -z "${CI_TEST}" ] ; then
  # Waiting Postgresql is up
  sqlup=1
  while [ "$sqlup" -ne 0 ] ; do
    echo "Waiting for postgresql..."
    pg_isready --host="${DB_HOST}" --port="${DB_PORT}" --user="${DB_ADMIN_USER}"
    if [ $? -ne 0 ] ; then
      sqlup=1
      sleep 5
    else
      sqlup=0
      echo "...postgresql is alive"
    fi
  done
fi

export PGUSER=${DB_ADMIN_USER}
export PGPASSWORD=${DB_ADMIN_PASSWORD}
export PGHOST=${DB_HOST}

[ -z "${DB_INIT}" ] && DB_INIT='false'
[ -z "${DB_UPDATE}" ] && DB_UPDATE='false'

# https://docs.bareos.org/IntroductionAndTutorial/InstallingBareos.html#other-platforms
# https://docs.bareos.org/TasksAndConcepts/CatalogMaintenance.html
#
if [ ! -f /etc/bareos/bareos-db.control ] && [ "${DB_INIT}" = 'true' ] ; then
  # Init BareOS Postgres DB using default 'postgres' admin user:
  # echo "Bareos Catalog/DB init"
  # su postgres -c /usr/lib/bareos/scripts/create_bareos_database 2>/dev/null
  # su postgres -c /usr/lib/bareos/scripts/make_bareos_tables 2>/dev/null
  # su postgres -c /usr/lib/bareos/scripts/grant_bareos_privileges 2>/dev/null
  echo "Bareos DB init"
  echo "Bareos DB init: Create user ${DB_USER}"
  psql -c "create user ${DB_USER} with createdb createrole login;"
  echo "Bareos DB init: Set user password"
  psql -c "alter user ${DB_USER} password '${DB_PASSWORD}';"
  /etc/bareos/scripts/create_bareos_database 2>/dev/null
  /etc/bareos/scripts/make_bareos_tables  2>/dev/null
  /etc/bareos/scripts/grant_bareos_privileges  2>/dev/null

  touch /etc/bareos/bareos-db.control
fi

if [ "${DB_UPDATE}" = 'true' ] ; then
  # Try Postgres upgrade
  echo "Bareoos DB update"
  echo "Bareoos DB update: Update tables"
  /etc/bareos/scripts/update_bareos_tables  2>/dev/null
  echo "Bareoos DB update: Grant privileges"
  /etc/bareos/scripts/grant_bareos_privileges  2>/dev/null
fi

# Run Dockerfile CMD
exec "$@"
