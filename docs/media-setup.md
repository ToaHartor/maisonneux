# Media environment setup

## Prerequisites

The media stack setup requires NFS storages for 

## Jellyfin wizard

As we can't bootstrap


### OIDC setup



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

