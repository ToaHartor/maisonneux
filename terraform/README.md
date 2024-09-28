# Server provisioning

## "static" environment

Deployment of static VMs and LXCs.

- Truenas VM to which a LSI HBA card is passed using a PCI passthrough, to manage storage which may be accessed from multiple machines (such as medias, important files or backups)
- "Nas" VM which is the old legacy microservice VM running Docker and using stacks from `docker-compose/`

## "k8s" environment

K8s cluster deployment on Proxmox using Terraform and Talos as OS, most parts including base image building and cluster configuration come from [this repository](https://github.com/rgl/terraform-proxmox-talos).

My k8s environment depends on the static environment, especially for storage provisioning with TrueNAS and a MinIO instance hosted on it. Some parts can be tuned and not be deployed, but this requires a manual modification to the charts in Terraform (democratic-csi and s3 csi would not be required).
