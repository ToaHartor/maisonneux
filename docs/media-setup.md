# Media environment setup

## Prerequisites

The media stack setup requires NFS storage mounts to persist downloads and medias in general.

The mount creation guide in TrueNAS is handled in nfs-mounts.md, so this is a prerequisite to the media environment.

## Qbittorrent setup

- In Downloads:
  - Set `Default save path` to `/downloads/complete`
  - Set `Keep incomplete torrents` to `/downloads/incomplete`
  - Set `Copy .torrent files` to `/downloads/torrentfiles`

TODO : VPN setup

## Jellyfin wizard

Jellyfin needs to be set up with the wizard. We create an admin user and password that will be used for the next steps to generate API keys.

Keep in mind that we can add additional users including admins using the OIDC provider.

### OIDC setup

Retrieve the oidc secret : `kubectl get secret/jellyfin-oidc-authentik-application -n jellyfin -o yaml`.

We can directly decode the data for our needs.

- OIDC id : `kubectl get secret/jellyfin-oidc-authentik-application -n jellyfin --output=jsonpath='{.data.clientID}' | base64 -d`
- OIDC secret : `kubectl get secret/jellyfin-oidc-authentik-application -n jellyfin --output=jsonpath='{.data.clientSecret}' | base64 -d`
- Issuer URL : `kubectl get secret/jellyfin-oidc-authentik-application -n jellyfin --output=jsonpath='{.data.issuerURL}' | base64 -d`

With the data from the secret, follow the setup with Authentik on Jellyfin's side.

- Name of the OID Provider : `Authentik`
- OID endpoint : issuer URL
- Client ID and secret : OIDC id and secret
- Roles :

```text
Admins
Media Users
```

- Admin Roles :

```text
Admins
```

- Enable role-based folder access

Do the folder mapping for each listed role and allow access in accordance to the groups.

- Role Claim

```text
groups
```

- Request Additional Scopes

```text
groups
```

- Scheme override : `https`

## Jellyseerr wizard

Jellyseerr requires a first setup after installation to link the Jellyfin server. Make sure to have intialized the Jellyfin server with a local admin user.

1. Go to the Jellyseerr main page
2. Select "Jellyfin" as the media server
3. In the Jellyfin wizard, enter the following :
   - Server url is `jellyfin.jellyfin.svc.cluster.local`. No SSL and default port 8096.
   - Admin email should point to the admin account email (e.g admin email of the cluster)
   - Admin user and email should correspond to the Jellyfin admin user

In the future, with OIDC support, we may have to assign groups automatically (admin users)

## Jellystat wizard

Despite providing a master user and password, it can only be used as a recovery account in case the admin user is lost.

Therefore, we have to go through the wizard to link the Jellyfin server.

0. Prerequisite : create an API key in the Jellyfin dashboard (Advanced > API keys).
1. Go to the Jellystat main page
2. Enter credentials to create the admin user and confirm
3. Enter `http://jellyfin.jellyfin.svc.cluster.local:8096` as the server `URL` and enter the created API key in `0.` in `API key`, then save details.
