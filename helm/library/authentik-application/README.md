---
title: "authentik-application"

description: "A Chart to deploy a secret for the authentik blueprint-sidecar."

---

# authentik-application

![Version: 0.4.3](https://img.shields.io/badge/Version-0.4.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

A Chart to deploy a secret for the authentik blueprint-sidecar.

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| WrenIX |  | <https://wrenix.eu> |

## Pre-Requirement
Usage of https://github.com/goauthentik/helm/pull/146

## or manual:
Install authentik with this `values.yaml`:
```yaml
serviceAccount:
  create: true

additionalContainers:
  - name: sidecar-blueprints
    image: "ghcr.io/kiwigrid/k8s-sidecar:1.25.1"
    env:
      - name: "FOLDER"
        value: "/blueprints/sidecar"
      - name: "LABEL"
        value: "goauthentik_blueprint"
      - name: "LABEL_VALUE"
        value: "1"
      # - name: "NAMESPACE"
      #   value: "ALL"
      - name: "RESOURCE"
        value: "both"
      - name: "UNIQUE_FILENAMES"
        value: "true"
    volumeMounts:
      - name: sidecar-blueprints
        mountPath: /blueprints/sidecar

volumeMounts:
  - name: sidecar-blueprints
    mountPath: /blueprints/sidecar

volumes:
  - name: sidecar-blueprints
    emptyDir: {}
```

And create an Role and bind them on to the ServiceAccount to read secrets:
```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: authentik-blueprint-sidecar
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: authentik-blueprint-sidecar
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: authentik-blueprint-sidecar
subjects:
  - kind: ServiceAccount
    name: authentik
```

## Usage

Helm must be installed and setup to your kubernetes cluster to use the charts.
Refer to Helm's [documentation](https://helm.sh/docs) to get started.
Once Helm has been set up correctly, fetch the charts as follows:

```bash
helm pull oci://codeberg.org/wrenix/helm-charts/authentik-application
```

You can install a chart release using the following command:

```bash
helm install authentik-application-release oci://codeberg.org/wrenix/helm-charts/authentik-application --values values.yaml
```

To uninstall a chart release use `helm`'s delete command:

```bash
helm uninstall authentik-application-release
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| blueprint.application.bindPolicyID | string | `nil` | uuid for bindPolicyID for group - if not set generated on secret for be stable (or groups: [] filled) |
| blueprint.application.description | string | `""` | description of application |
| blueprint.application.group | string | `""` | put this application in authentik in group |
| blueprint.application.icon | string | `""` | icon of application (url) |
| blueprint.application.launchURL | string | `""` |  |
| blueprint.application.name | string | `""` | application name in menu |
| blueprint.application.openInNewTab | bool | `false` | open application in new tab |
| blueprint.application.policyEngineMode | string | `"any"` |  |
| blueprint.application.publisher | string | `""` | publisher of application |
| blueprint.application.slug | string | `"app-name"` | application slug |
| blueprint.authentik.domain | string | `"https://auth.wrenix.eu"` | domain to authentik, used in generated url (like issuer) |
| blueprint.groups | string | `nil` | authentik groups created / give access to this application  disable any groups by set groups: [] (to a slice) example:   - slug: "app: grafana-admin"     parent: "app: infra"     bindID: uuid  |
| blueprint.labels | object | `{"goauthentik_blueprint":"1"}` | label of generated secret with blueprint |
| blueprint.provider.authorizationFlow | string | `"default-provider-authorization-implicit-consent"` |  |
| blueprint.provider.enabled | bool | `true` | creat an provider for authentification (otherwise just a like in menu is created) |
| blueprint.provider.name | string | `""` |  |
| blueprint.provider.oidc.clientID | string | `nil` | client id - generated if secret enabled |
| blueprint.provider.oidc.clientSecret | string | `nil` | client secret - generated if secret enabled |
| blueprint.provider.oidc.clientType | string | `"confidential"` |  |
| blueprint.provider.oidc.redirectURL | string | `""` |  |
| blueprint.provider.oidc.scopes | string | `nil` | Scope |
| blueprint.provider.oidc.signingKey | string | `""` | Need for non-curve / RSA |
| blueprint.provider.proxy.cookieDomain | string | `""` |  |
| blueprint.provider.proxy.externalHost | string | `nil` |  |
| blueprint.provider.proxy.ingress.annotations | list | `[]` | annotations to ingress for outpost |
| blueprint.provider.proxy.ingress.backend | string | `"authentik"` | service backend to authentik |
| blueprint.provider.proxy.ingress.domain | string | `nil` | domain of application (where outpost should be deployed) |
| blueprint.provider.proxy.ingress.enabled | bool | `false` | deploy ingress on application domain for e.g. logout (WIP) |
| blueprint.provider.proxy.ingress.tls | list | `[]` | tls to ingress for outpost |
| blueprint.provider.proxy.skipPathRegex | string | `""` |  |
| blueprint.provider.saml | string | `nil` |  |
| blueprint.provider.type | string | `"oidc"` | type of application connection, current support: oidc, saml and proxy |
| secret.labels | object | `{}` | label of secret to store generated secret |
| secret.name | string | `""` | name of secret to store generated secret (like clientI) |

Autogenerated from chart metadata using [helm-docs](https://github.com/norwoodj/helm-docs)

