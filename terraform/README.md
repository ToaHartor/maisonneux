# Server provisioning

## "static" environment

Deployment of static VMs and LXCs.

- Truenas VM to which a LSI HBA card is passed using a PCI passthrough, to manage storage which may be accessed from multiple machines (such as medias, important files or backups)
- "Nas" VM which is the old legacy microservice VM running Docker and using stacks from `docker-compose/`

## "k8s" environment

K8s cluster deployment on Proxmox using Terraform and Talos as OS, most parts including base image building and cluster configuration come from [this repository](https://github.com/rgl/terraform-proxmox-talos).

My k8s environment depends on the static environment, especially for storage provisioning with TrueNAS and a MinIO instance hosted on it. Some parts can be tuned and not be deployed, but this requires a manual modification to the charts in Terraform (democratic-csi and s3 csi would not be required).

## Setting up the environment

### Terraform access to the cluster

Some operations require the Root user to be used to modify some rules (such as PCI passthrough), so the following method with a token may not work for the static environment, prefer using the username/password method.

Procedure to create a token :

```txt
# Create the user
sudo pveum user add terraform@pve
# Create a role for the user above
sudo pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt User.Modify"
# Assign the terraform user to the above role
sudo pveum aclmod / -user terraform@pve -role Terraform
# Create the token
sudo pveum user token add terraform@pve provider --privsep=0
```
