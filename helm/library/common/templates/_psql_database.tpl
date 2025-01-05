{{/* Template used to generate a database in an existing cloudnativepg cluster
Parameters :
- .DatabaseNamespace : Database namespace
- .DatabaseName : Database name
- .DatabaseOwner : Database owner
- .PsqlClusterName : Postgres cluster name
*/}}
{{- define "common.psqldb" -}}
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: {{ .DatabaseName }}
  namespace: {{ .DatabaseNamespace }}
spec:
  name: {{ .DatabaseName }}
  ensure: present
  owner: {{ .DatabaseOwner }}
  cluster:
    name: {{ .PsqlClusterName }}
{{- end -}}