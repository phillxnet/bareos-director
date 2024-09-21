# Bareos Director

Bareos (Backup Archiving REcovery Open Sourced) Architecture overview: https://www.bareos.com/software/

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

## Container User context

The Bareos 'Director' normally runs as the `bareos` user & primary group,
which are created by the packages themselves.
In this image's case we create them beforehand to ensure know UID:GID; see next subsection. 
The additional groups of disk,tape are also expected for the Storage daemon specifically.

> groups bareos' returns: "bareos : bareos disk tape"

### Host User configuration

This image uses the dockerfile [USER](https://docs.docker.com/reference/dockerfile/#user) directive.
A matching host user:group (by UID & GID) of 105:105 is required on the container host system.

As container to host mapping is via UID:GID only,
it is required to be explicit: enabling mapped volumes' permissions,
and in the case of the Storage daemon specifically,
special capabilities & (disk,tape) group membership.

To create a container matching 'bareos' group (gid=105) execute:
```shell
groupadd --system --gid 105 bareos
```
And to create the matching 'bareos' user (uid=105) in this group, with supplementary groups disk,tape:
```shell
useradd --system --uid 105 --comment "bareos" --home-dir /var/lib/bareos -g bareos -G disk,tape --shell /bin/false bareos
```
N.B. in the above, /var/lib/bareos is not required or created on the host.

## Environmental Variables

### Remote Catalog (Postgres DB container)
https://hub.docker.com/_/postgres

**Admin credentials for DB init**
(var baros - var postgres)
- DB_ADMIN_USER = 'postgres' default admin user in official postgres container
- DB_ADMIN_PASSWORD = POSTGRES_PASSWORD (from 'postgres:14' docker image)

**Create new Catalog/DB**
If /etc/bareos/bareos-db.control does not exist,
and this flag is 'true' created the required Catalog/DB,
and finally create the flag file /etc/bareos/bareos-db.control.
- DB_INIT: 'true' enables the creation of a new default Catalog (MyCatalog).

**Remote DB authentication via .pgpass file** 
- DB_HOST: postgres container name (bareos-db)
- DB_PORT: port (default 5432) of DB_HOST
- DB_NAME: bareos database name (bareos)
- DB_USER: bareos database user (bareos)
- DB_PASSWORD: DB_USER password for DB_NAME database access

### Storage/File daemon credentials

- BAREOS_SD_HOST/BAREOS_SD_PASSWORD 
- BAREOS_FD_HOST/BAREOS_FD_PASSWORD

### Bconsole CLI client config

This container includes a local bconsole client install,
pre-configured via upstream package scripts with this containers 'Director' credentials.
See:
- /etc/bareos/bareos-dir.d/director/bareos-dir.conf
- /etc/bareos/bconsole.conf

### WEBUI credentials

- BAREOS_WEBUI_PASSWORD

## Local Build
- -t tag <name>
- . indicates from-current directory

```
docker build -t bareos-dir .
```

## Required Catalog (Postgres DB) via container

### dev-net
Docker network to enable inter container communication:
```shell
docker network create bareosnet
docker network list
docker network inspect bareosnet
# and to remove:
docker network remove bareosnet
```

### bareos-db
Example docker invocation of Postgres 14 as our 'remote' Catalog DB host:
```shell
docker run --name bareos-db -e POSTGRES_PASSWORD=pg-admin-pass -e POSTGRES_INITDB_ARGS=--encoding=SQL_ASCII\
 -v ./catalog:/var/lib/postgresql/data --network=bareosnet -d postgres:14
# and to remove
docker remove bareos-db
```

## Run Director container 

```shell
# skip entrypoint and run 'sh' instead:
docker run --name bareos-dir -u 105 -it --entrypoint sh bareos-dir
# Mount e.g. local ./config & ./data dirs (bareos:bareos assumed) at /etc/bareos & /var/lib/bareos within container:
# Non-production passwords for testing only:
docker run --name bareos-dir -u 105 -it\
 -e DB_ADMIN_USER='postgres' -e DB_ADMIN_PASSWORD='pg-admin-pass'\
 -e DB_HOST='bareos-db' -e DB_PORT='5432' -e DB_NAME='bareos' -e DB_USER='bareos' -e DB_PASSWORD='bareos-db-user-pass'\
 -e DB_INIT='true'\
 -e BAREOS_SD_HOST='bareos-sd' -e BAREOS_SD_PASSWORD='bareos-sd-pass'\
 -e BAREOS_FD_HOST='bareos-fd' -e BAREOS_FD_PASSWORD='bareos-fd-pass'\
 -e BAREOS_WEBUI_PASSWORD='webui-pass'\
 -v ./config:/etc/bareos -v ./data:/var/lib/bareos\
 --network=bareosnet bareos-dir sh
# and to remove
docker remove bareos-dir
```

## Interactive shell / bconsole

Once the bareos-dir container is running:
```
docker exec -it bareos-dir sh
# Director's 'localhost' bconsole:
bconsole
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