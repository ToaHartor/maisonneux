# Central postgres database

- Database creation in postgres namespace
- Role creation in cluster (for now), will be created alongside database resources in apps, created in postgres namespace
- Secrets should be accessible from both postgres namespace and app namespace : use external-secrets namespace, or existing postgres namespace and create a clustersecretstore there
  - New ClusterSecretStore is more adequate, and create an externalsecret in the app namespace
  - For now, since roles are created in the postgres Cluster resource, we have to create secrets there as well, but when roles crd becomes available, create them in apps
