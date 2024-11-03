# Maisonneux

Setup of my personal homelab ("maisonneux" can be _jokingly_ translated to "homies" in French).

I first started with a simple server with OpenMediaVault with Docker configured in the UI, then migrated to the stacks available in the folder `docker-compose/`.

After some years and an upgrade on the server (more RAM and a new CPU), I migrated the entire server to [Proxmox](https://www.proxmox.com/en/) in a single [Debian](https://www.debian.org/) VM to keep the services running, then move the storage management to a [TrueNAS Core](https://www.truenas.com/) VM and the microservices in a Kubernetes cluster using [Talos Linux](https://www.talos.dev/).

The provisioning of the virtual machines as well as LXCs in Proxmox is done with [OpenTofu](https://opentofu.org/) (or Terraform) using the [Proxmox provider](https://github.com/bpg/terraform-provider-proxmox).

The main operations (cluster and VM provisioning) are performed using the `Makefile` at the root of the repository. Help command is coming soon*tm*.

---

## Repository organization

- `docker-compose/` contains the former stacks I used to manage my microservices. See [this page](docker-compose/README.md) for to see the list of microservices deployed.
- `helm/` contains the Helm charts used to deploy some microservices in K8s
- `scripts/` contains scripts used to setup environment, check health of services or build images
- `terraform/` contains a multi-environment . Static environment deploys static VMs and LXCs (such as the storage VM), and K8s environment deploys a Kubernetes cluster. See [this page](terraform/README.md) for more informations.

### Cluster directories

Each directory represents a deployment stage, contains a folder for production and staging environments.

- `clusters/` : FluxCD configurations, contains Kustomization definitions for other stages
- `system/` : Core cluster components, CSI drivers
- `platform/` : Database operators, storage operators
- `core/` : Ingress, Identity provider
- `apps/` : Mostly internet facing apps

## Issues

Issues are not opened, as I'm not supposed to give support for the softwares/technologies I'm using. For that, please refer to their own repositories or forums. However, I'm open to any advice and discussion in the Discussion section.

## Tools

- Terraform/[OpenTofu](https://opentofu.org/)
- [Talosctl](https://www.talos.dev/install)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [K9s](https://k9scli.io/topics/install/)
- [Docker](https://www.docker.com/)
- [helm](https://helm.sh/)
- [helmfile](https://github.com/helmfile/helmfile)
