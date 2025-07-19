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

{{/*
Generate secret containing a secret key
Parameters :
- SecretName : secret name (and target name)
- SecretNamespace : secret namespace
- SecretType : secret type (either apiKey or token, optional)
- AdditionalLabels : additional labels to add to the key (optional)

Usage :
{{- include "common.secret.key" (dict "SecretName" .Name "SecretNamespace" .Release.Namespace) }}
*/}}
{{- define "common.secret.key" -}}
{{- $secretType := default "token" .SecretType -}}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .SecretName }}
  namespace: {{ .SecretNamespace }}
  {{- with .AdditionalLabels }}
  labels:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  refreshPolicy: CreatedOnce
  dataFrom:
  - sourceRef:
      generatorRef:
        apiVersion: generators.external-secrets.io/v1alpha1
        kind: ClusterGenerator
        name: {{ ternary "api-key" "secret-key" (eq $secretType "apiKey")}}

  target:
    template:
      {{- with .AdditionalLabels }}
      metadata:
        labels:
          {{- toYaml . | nindent 10 }}
      {{- end }}
      data:
        secretKey: "{{ `{{ .password }}` }}"
      engineVersion: v2
{{- end }}

{{/*
Generate secret containing a username and a password
Parameters :
- Username
- SecretName : secret name (and target name)
- SecretNamespace : secret namespace

Usage :
{{- include "common.secret.creds" (dict "Username" .User.name "SecretName" .Name "SecretNamespace" .Release.Namespace) }}
*/}}
{{- define "common.secret.creds" -}}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .SecretName }}
  namespace: {{ .SecretNamespace }}
  labels:
    homelab/backup-resource: "true"
spec:
  refreshPolicy: OnChange
  dataFrom:
  - sourceRef:
      generatorRef:
        apiVersion: generators.external-secrets.io/v1alpha1
        kind: ClusterGenerator
        name: "password"
  target:
    template:
      metadata:
        labels:
          homelab/backup-resource: "true"
      data:
        username: "{{ .Username }}"
        password: "{{ `{{ .password }}` }}"
      engineVersion: v2
{{- end }}