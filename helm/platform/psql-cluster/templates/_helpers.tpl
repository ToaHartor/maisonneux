# Inlined from helm/library/common/templates/_secrets.tpl - psql-cluster is kept
# self-contained (no file:// chart deps) so offline renderers (flate) work.
# Keep in sync with the library if common.secret.creds changes.
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