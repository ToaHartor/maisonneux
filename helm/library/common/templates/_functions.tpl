{{/*
Function to split a domain with its protocol
E.g. : https://www.example.com 
Returns : dict "Protocol" https "Domain" www.example.com

Usage :
{{- $dict := include "common.func.split-domain" (dict "Domain" .domain) | fromJson }}

*/}}
{{- define "common.func.split-domain" -}}
{{- $splitRes := split "://" .Domain -}}
{{- $result := dict "Protocol" $splitRes._0 "Domain" $splitRes._1 }}
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