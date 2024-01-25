# Maisonneux

Personal collection of stacks and configs for a home server ("maisonneux" can be *jokingly* translated to "homies" in French)

---

This repository contains the configuration and documentation I collected while refactoring my stacks, moving from nginx to Traefik, and adding a centralized authentication service with Authentik.

Users can login to Authentik with their Plex account, therefore an Authentik account is automatically created if the user has access to the Plex server selected in the config. It allows them to have access to the Plex stack with SSO (auto login on Organizr using Proxy auth, and Plex/Tautulli/Overseerr with custom scope mapping in Authentik).
However, it requires to import Plex users in Organizr, Tautulli and Overseerr.

They are also able to add a password and a two-factor authentication method to login on Plex without needing to go though the Plex pop-up.

Access to the services are configured and restricted in Authentik, as we use the *Forward auth with Single application* proxy provider for apps having the forward auth middleware in their Traefik config, and the OIDC/OAuth2 provider for apps which have an account system.

## Issues

Issues are not opened, as I'm not supposed to give support for the softwares/Dockers I'm using. For that, please refer to their own repositories. However, I'm open to any advice and discussion in the Discussion section.

## TO-DO List

- [ ] Health checks in compose
- [ ] Finish Adguard config
- [ ] Backup setup (Kopia ?)
- [X] Migration to InfluxDB 2
- [X] Try Kavita as book server (Komga alternative)
- [ ] Docker secrets or vault usage
- [X] Use a Docker proxy for applications requiring access to `docker.sock`

## Softwares used

Strikethrough softwares are no longer part of my stacks, but the composes are still in this repository.

### Server core

|Functionality|Name|Link|Stack|Auth provider in Authentik|
|-|-|-|-|-|
|Reverse proxy|Traefik|<https://github.com/traefik/traefik>|proxy-auth|Proxy for the dashboard|
|~~Reverse proxy (formerly)~~|~~NGINX (SWAG docker)~~|~~<https://github.com/linuxserver/docker-swag>~~|~~proxy-auth~~||
|Authentication server|Authentik|<https://github.com/goauthentik/authentik>|proxy-auth|Integrated|
|Network adblock (WIP)|Adguard Home|<https://github.com/AdguardTeam/AdGuardHome>|proxy-auth||
|Home dashboard|Organizr|<https://github.com/causefx/Organizr>|proxy-auth|Proxy with scope mapping|
|Service themes|theme.park|<https://github.com/GilbN/theme.park>|proxy-auth|None|
|Backup solution (WIP)|Kopia|<https://github.com/kopia/kopia>|backup||
|Docker socket proxy|Docker socket proxy|<https://github.com/Tecnativa/docker-socket-proxy>|proxy-auth||
|Homepage (WIP)|Homepage|<https://github.com/benphelps/homepage>|proxy-auth|Not exposed|

### Media management

|Functionality|Name|Link|Stack|Auth provider in Authentik|
|-|-|-|-|-|
|PVR/TV series managemenent|Sonarr|<https://github.com/Sonarr/Sonarr>|media|Proxy with basic auth|
|PVR/Movies management|Radarr|<https://github.com/Radarr/Radarr>|media|Proxy with basic auth|
|PVR/Music management|Lidarr|<https://github.com/Lidarr/Lidarr>|media|Proxy with basic auth|
|Manga chapter tagging|Mangatagger|From this fork <https://github.com/Banh-Canh/Manga-Tagger>|media|Proxy with basic auth|
|Indexer|Prowlarr|<https://github.com/Prowlarr/Prowlarr>|media|Proxy with basic auth|
|~~Indexer (formerly)~~|~~Jackett~~|~~<https://github.com/Jackett/Jackett>~~|~~media~~||
|Plex user/library statistics|Tautulli|<https://github.com/Tautulli/Tautulli>|media|Proxy with scope mapping|
|TV/Movies requesting|Overseerr|<https://github.com/sct/overseerr>|media|Proxy with scope mapping|
|Manga downloader/manager (WIP)|Kaizoku|<https://github.com/oae/kaizoku>|media|Not exposed|
|Live TV proxy|xTeVe|<https://github.com/xteve-project/xTeVe>|media|Not exposed|

### Media servers

|Functionality|Name|Link|Stack|Auth provider in Authentik|
|-|-|-|-|-|
|TV/Movie/Music server|Plex|<https://www.plex.tv>|*|Proxy with scope mapping|
|~~Manga server (formerly, so long because Java)~~|~~Komga~~|~~<https://github.com/gotson/komga>~~|~~media~~|~~None, but might support OIDC~~|
|Manga server|Kavita|<https://github.com/Kareadita/Kavita>|media|None|

Note*: Plex is not deployed with Docker here, to avoid any problems with hardware transcoding (and removes the headache of having a NVIDIA docker)

### Download clients

|Functionality|Name|Link|Stack|Auth provider in Authentik|
|-|-|-|-|-|
|Torrent client|Transmission|<https://github.com/transmission/transmission>|media|None|
|~~Torrent client (formerly)~~|~~qBitTorrent~~|~~<https://github.com/qbittorrent/qBittorrent>~~|~~media~~||
|Torrent client frontend|Flood|<https://github.com/jesec/flood>|media|Proxy with basic auth|
|DDL client|JDownloader2|Dockerized version <https://github.com/jlesage/docker-jdownloader-2>|media|Proxy|
|Manga downloader|FMD2|<https://github.com/dazedcat19/FMD2>, Dockerized version <https://github.com/Banh-Canh/docker-FMD2>|media|Proxy|

### Services

|Functionality|Name|Link|Stack|Auth provider in Authentik|
|-|-|-|-|-|
|File server|Seafile|<https://github.com/haiwen/seafile>|cloud|OIDC|
|~~File server (formerly)~~|~~Nextcloud~~|~~<https://github.com/nextcloud/server>~~|~~cloud~~|~~OIDC~~|
|Document editor|OnlyOffice|<https://github.com/ONLYOFFICE/DocumentServer>|cloud|None, but only apps with the JWT token can use it|
|Finances manager|Firefly III|<https://github.com/firefly-iii/firefly-iii>|services|Not exposed|
|Documentation/Wiki|Bookstack|<https://github.com/BookStackApp/BookStack>|services|OIDC|
|Documentation/Wiki|Outline|<https://github.com/outline/outline>|services|OIDC|
|Spreadsheet Server|Grist|<https://github.com/gristlabs/grist-core>|services|OIDC|
|Git/Code repository server|Gitea|<https://github.com/go-gitea/gitea>|services|OIDC|
|Password manager|Vaultwarden|<https://github.com/dani-garcia/vaultwarden>|services|None|
|Coding server|Code-server|<https://github.com/coder/code-server>|services|Not exposed|
|Recipes|Tandoor|<https://github.com/TandoorRecipes/recipes>|services|None|
|Notifications|Gotify|<https://github.com/gotify/server>|services|Not exposed|
|Cryptography utilities|Cyberchef|<https://github.com/gchq/CyberChef>, Dockerized version <https://github.com/mpepping/docker-cyberchef/>|services|Not exposed|
|Photo server|Immich|<https://github.com/immich-app/immich>|services|OIDC|
|Database manager|Cloudbeaver|<https://github.com/dbeaver/cloudbeaver>|databases|Not exposed|
|Document management|Paperless-ngx|<https://github.com/paperless-ngx/paperless-ngx>|services|Not exposed|
|S3 compatible storage|MinIO|<https://github.com/minio/minio>|services|OIDC|
|Notes/Memo|Memos|<https://github.com/usememos/memos>|services|OIDC|
|Coding statistics|Wakapi|<https://github.com/muety/wakapi>|services|None|
|Game distribution|Gamevault|<https://github.com/Phalcode/gamevault-backend>|services|None|
|PDF multitool|Stirling-pdf|<https://github.com/Stirling-Tools/Stirling-PDF>|services|Not exposed|

### Monitoring

|Name|Required by|Link|Stack|Auth provider in Authentik|
|-|-|-|-|-|
|Metrics aggregation|Telegraf|<https://github.com/influxdata/telegraf>|*|-|
|Tautulli/Arr/Overseerr metric aggregator|Varken|Develop branch is still active here <https://github.com/Boerderij/Varken/tree/develop>|monitoring|-|
|Monitoring dashboard + alerting|Grafana|<https://github.com/grafana/grafana>|monitoring|OIDC|
|Disk monitoring|Scrutiny|<https://github.com/AnalogJ/scrutiny>|monitoring|None (local)|
|Logs aggregator|Promtail+Loki|<https://github.com/grafana/loki>|monitoring|-|

Note*: Telegraf is directly installed on the server, making the  metric collection permissions easier, limiting problems that could happen while collecting metrics.

### Databases

|Name|Required by|Link|Stack|
|-|-|-|-|
|MariaDB|Seafile, Nextcloud, Gitea, Firefly III, Bookstack|<https://github.com/MariaDB/server>|databases|
|PostgreSQL|Tandoor, Immich, Authentik|<https://github.com/postgres/postgres>|databases, proxy-auth|
|MongoDB|Mangatagger|<https://github.com/mongodb/mongo>|databases|
|Redis|Paperless-ngx, Immich, Authentik, Nextcloud|<https://github.com/redis/redis>|databases, proxy-auth|
|InfluxDB|Telegraf, Varken, Grafana, Traefik (to post metrics)|<https://github.com/influxdata/influxdb>|databases, monitoring|

### Thanks to

- All repositories mentioned above, their documentation and repository issues
- [This](https://github.com/htpcBeginner/docker-traefik) repository from htpcBeginner, which helped me a lot to understand some Traefik configuration, and from where the security policies comes.
