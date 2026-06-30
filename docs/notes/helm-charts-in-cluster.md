# Helm charts in cluster

The main goal is to move from a classic Helm deployment with helmfile to orchestrate everything, to a GitOps approach. We want to control and be able to update lot of things using the GitOps engine (Helm charts of core components for instance).

## What can be moved

- cert-manager => can be migrated (still needs privileged namespace but can be allowed in talos cfg)
- cert-manager-csi-driver => can be migrated (same)
- cilium => might be able to be managed by gitops, but needs to be set up for the cluster
- democratic-csi => can be migrated (needs privileges iirc)
- proxmox-csi => can be migrated (needs privileges)
- s3-csi => can be migrated (might need privileges)
- reloader => can be migrated
- trust-manager => can be migrated like cert-manager

First, study how can the certificates be managed at cert-manager init (might have no needs for those we generate)

Establish a hierarchy for gitops : in which order should those charts be deployed ?

1. Cluster deployment (e.g. cilium) => not really managed by FluxCD/ArgoCD
2. System => Core and cluster charts : csi-drivers, GitOps operators, storage operators, vault ?
3. Core apps => Ingress (traefik), Identity Provider, database operators
4. Public apps => Everything else (media, services, databases, game servers)

## Deployment order

1. System : Core cluster, CSI drivers
2. Platform : Database operators, storage operators
3. Core : Ingress, Identity provider
4. Apps : Mostly internet facing apps

## How to manage secrets with GitOps

"2" methods :

- Encrypt with sealed secrets/sops and commit to repository : meh and not very generic (+ relies on the fact that it's secure)
- External source which is provided manually (like for a cluster provisioning)
  - Should the vault be provisioned at the same time as the cluster / CD tools ? Init = Yes imo (same as Helm values)
  - How can we update values inside ? (via API but should be done manually for external secrets, in some way it's not really a problem as external secrets are provided manually anyway)
  - How can the vault be managed by our GitOps friend ? This should be the first thing it should deploy
  - How can we manage dependencies of it (Database) ? Either use the embed one inside or GitOps should deploy the db operator first THEN the Vault then use the vault for all the other deployments
    - Therefore, the order would be : CD => Storage Operators (maybe provisioned with the cluster, secrets)
        => DB Operators (need StorageClass) => Vault (needs DB, generate password) => Everything else (that relies on secrets from the Vault)
  - How can we wait for the Vault to be online to provision it while CD is running : Big question ???
    In theory helm deployments will try and fail until a secret is populated, so this should be safe until we provide all the secrets

=> Choice : Provision Secrets and ConfigMap with FluxCD init using Terraform, allowing them to not be stored in a Git repository. Not a problem since we provision our k8s cluster with Terraform as well.
