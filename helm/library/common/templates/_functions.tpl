{{/*
Function to split an external url with its protocol and port
E.g. : https://www.example.com:443
Returns : dict "Protocol" https "Domain" www.example.com "Port" 443
If there is no port in domain, "Port" = 0

Usage :
{{- $dict := include "common.func.split-externalurl" (dict "Domain" .domain) | fromJson }}

*/}}
{{- define "common.func.split-externalurl" -}}
{{- $splitRes := split "://" .Domain -}}
{{- $splitDomainPort := split ":" $splitRes._1 -}}
{{- $result := dict "Protocol" $splitRes._0 "Domain" $splitDomainPort._0 "Port" (ternary $splitDomainPort._1 0 (gt (len $splitDomainPort) 1))}}
{{- $result | toJson}}
{{- end }}

{{/*
Function to split a domain to return the main and subdomain
E.g. : www.main.example.com
Returns : dict "Subdomain" www "Domain" main.example.com

Usage :
{{- $dict := include "common.func.split-domain" (dict "Domain" .domain) | fromJson }}

*/}}
{{- define "common.func.split-domain" -}}
{{- $splitRes := splitn "." 2 .Domain -}}
{{- $result := dict "Subdomain" $splitRes._0 "Domain" $splitRes._1 }}
{{- $result | toJson}}
{{- end }}

{{/*
Function to generate database credential name
- DatabaseUser : user name in the database
*/}}
{{- define "common.db.secret-name" -}}
{{ printf "%s-db-creds" .DatabaseUser }}
{{- end }}

{{/*
Get database user credentials from database cluster secret store
- Namespace : namespace where the secret should be placed
- SecretName : secret name (and target name)
- ClusterSecretName : name of the cluster secret score
*/}}
{{- define "common.db.extsecret" -}}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .SecretName }}
  namespace: {{ .Namespace }}
spec:
  dataFrom:
    - extract:
        key: {{ .SecretName }}
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: {{ .ClusterSecretName }}
  target:
    name: {{ .SecretName }}
    creationPolicy: Owner
    deletionPolicy: Retain
{{- end }}