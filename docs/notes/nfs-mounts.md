# NFS mounts in cluster

Listed mounts :

- download
- media_(1/2/3...)
- immich
- paperless
- seafile

Create a user which will have the id 1000, and its associated group with id 1000

## Mount creation in TrueNAS

Folder permissions : Owner : 1000; Group 1000; permissions 774 (groups allowed to write can ease restrictions, like for jdownloader)

All containers using NFS mounts use 1000:1000 as their runtime user.

Seafile runs as 0:0 inside as rootless does not seem to work, so the seafile mount is owned by root:wheel instead.

## NFS share

Use mapall users : 1000 and mapall groups : 1000.
