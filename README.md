# BareOS Director

Follows Bareos's own install instructions as closely as possible: given container limitations.
Initially uses only Bareos distributed community packages [Bareos Community Repository](https://download.bareos.org/current) `Current` variant.

Intended future capability, upon instantiation, is to use the [Official Bareos Subscription Repository](https://download.bareos.com/bareos/release/),
if non-empty subscription credentials are passed by environmental variables.

See: [Decide about the Bareos release to use](https://docs.bareos.org/IntroductionAndTutorial/InstallingBareos.html#decide-about-the-bareos-release-to-use)

Based on opensuse/leap:15.6 as per BareOS instructions:
[SUSE Linux Enterprise Server (SLES), openSUSE](https://docs.bareos.org/IntroductionAndTutorial/InstallingBareos.html#install-on-suse-based-linux-distributions)

Inspired & informed by the many years of Bareos container maintenance done by Marc Benslahdine https://github.com/barcus/bareos, and contributors.

This images /etc/bareos is intended to be shared by same-author storage, webui, and dir-local-file containers.
The intention here is to simplifying/containerise a Bareos server set deployment:
i.e. Director/Catalog/Storage/File/WebUI server set

## Environmental Variables

### Remote Catalog (Postgres DB container)
https://hub.docker.com/_/postgres

**Admin credentials for DB init**
(var baros - var postgres)
- DB_ADMIN_USER = 'postgres' (default) admin user in postgres container
- DB_ADMIN_PASSWORD = POSTGRES_PASSWORD (from postgres image)

**Remote DB authentication via .pgpass file** 
- DB_HOST: postgres container name (bareos-db)
- DB_PORT: port (default 5432) of DB_HOST
- DB_NAME: bareos database name (bareos)
- DB_USER: bareos database user (bareos)
- DB_PASSWORD: DB_USER password for DB_NAME database access

### Storage/File daemon credentials

- BAREOS_SD_HOST/BAREOS_SD_PASSWORD 
- BAREOS_FD_HOST/BAREOS_FD_PASSWORD

### WEBUI credentials

- BAREOS_WEBUI_PASSWORD

## Local Build
- -t tag <name>
- . indicates from-current directory

```
docker build -t bareos-director .
```

## Local Run

```
docker run --name bareos-director
# skip entrypoint and run shell
docker run -it --entrypoint sh bareos-director
```

## Interactive shell

```
docker exec -it bareos-director sh
```

## BareOS rpm package scriptlet actions

### bareos-director
```shell
Info: replacing 'XXX_REPLACE_WITH_LOCAL_HOSTNAME_XXX' with '86bf077fd97b' in /etc/bareos/bareos-dir.d/storage/File.conf
Info: replacing 'XXX_REPLACE_WITH_DIRECTOR_PASSWORD_XXX' in /etc/bareos/bareos-dir.d/director/bareos-dir.conf
Info: replacing 'XXX_REPLACE_WITH_CLIENT_PASSWORD_XXX' in /etc/bareos/bareos-dir.d/client/bareos-fd.conf
Info: replacing 'XXX_REPLACE_WITH_STORAGE_PASSWORD_XXX' in /etc/bareos/bareos-dir.d/storage/File.conf
Info: replacing 'XXX_REPLACE_WITH_DIRECTOR_MONITOR_PASSWORD_XXX' in /etc/bareos/bareos-dir.d/console/bareos-mon.conf
```

### bareos-bconsole
```shell
Info: replacing 'XXX_REPLACE_WITH_DIRECTOR_PASSWORD_XXX' in /etc/bareos/bconsole.conf
```