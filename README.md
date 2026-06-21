# Maisonneux

Setup of my personal homelab ("maisonneux" can be _jokingly_ translated to "homies" in French).

I first started with a simple server with OpenMediaVault with Docker configured in the UI, then migrated to the stacks available in the folder `docker-compose/`.

After some years and an upgrade on the server (more RAM and a new CPU), I migrated the entire server to [Proxmox](https://www.proxmox.com/en/) in a single [Debian](https://www.debian.org/) VM to keep the services running, then move the storage management to a [TrueNAS Core](https://www.truenas.com/) VM and the microservices in a Kubernetes cluster using [Talos Linux](https://www.talos.dev/).

The provisioning of the virtual machines as well as LXCs in Proxmox is done with [OpenTofu](https://opentofu.org/) (or Terraform) using the [Proxmox provider](https://github.com/bpg/terraform-provider-proxmox).

The main operations (cluster and VM provisioning) are performed using `mise`.

---

## Repository organization

- `docker-compose/` contains the former stacks I used to manage my microservices. See [this page](docker-compose/README.md) for to see the list of microservices deployed.
- `helm/` contains the Helm charts used to deploy some microservices in K8s
- `scripts/` contains scripts used to setup environment, check health of services or build images
- `terraform/` contains a multi-environment . Static environment deploys static VMs and LXCs (such as the storage VM), and K8s environment deploys a Kubernetes cluster. See [this page](terraform/README.md) for more informations.
- `kubernetes/` contains the deployment manifests for apps in kubernetes

### Cluster directories

In the `kubernetes/` directory, each folder represents a deployment stage, contains a folder for production and staging environments.

- `clusters/` : FluxCD configurations, contains Kustomization definitions for other stages
- `system/` : Core cluster components, CSI drivers
- `platform/` : Database operators, storage operators
- `core/` : Ingress, Identity provider
- `apps/` : Mostly internet facing apps

FluxCD reads the files in `clusters/{env}` then each describing a deployment stage points to a folder containing a Kustomization referencing the common .yaml files and eventual particularities.

## Tools

All the required tools are managed and versioned by [mise](https://github.com/jdx/mise).

To install the tools, use

```bash
mise install
mise run venv
```

## Development

Push a dev branch to the Forgejo instance in the cluster :

- Import a public SSH key in Forgejo in the User settings
- Create the new repository in Forgejo
- Create a new origin to the new repo (`git remote add forgejo ssh://git@forge.<domain>:2222/<user>/maisonneux.git`)
- Create a new branch from `main` (in my case it corresponds to the one in forgejo workloads : `localdev`)
- Set the new branch origin to our Forgejo origin (`git push -u forgejo <branch>`)
- Allow the `renovate` user to access this repository (as admin) to be able to create component update PRs and webhook
- Add the topic "renovate" to the repository (**Manage topics** under the description of the repository)

To allow FluxCD to source this repository to self-deploy the cluster :

- Create a new user in Forgejo
- Give access to the repository to this user (read only is enough)
- Change the terraform vars :
  - flux_git_user : account username
  - flux_git_token : account password
  - flux_git_branch : `localdev`
  - flux_git_remote_protocol : `http`
  - flux_git_remote_domain : `forge.<domain>`
  - flux_git_remote_port : `443`
  - flux_git_repository : `<user>/maisonneux`

## Issues

Issues are not opened, as I'm not supposed to give support for the softwares/technologies I'm using. For that, please refer to their own repositories or forums. However, I'm open to any advice and discussion in the Discussion section.
