# Jellyseerr wizard

Jellyseerr requires a first setup after installation to link the Jellyfin server. Make sure to have intialized the Jellyfin server with a local admin user.

1. Go to the Jellyseerr main page
2. Select "Jellyfin" as the media server
3. In the Jellyfin wizard, enter the following :
   - Server url is `jellyfin.jellyfin.svc.cluster.local`. No SSL and default port 8096.
   - Admin email should point to the admin account email (e.g admin email of the cluster)
   - Admin user and email should correspond to the Jellyfin admin user
