{{/* Template used to generate a database in an existing mariadb cluster
Parameters :
- .DatabaseNamespace : Database namespace
- .DatabaseName : Database name
- .ClusterName : MariaDB cluster name
*/}}
{{- define "common.mariadb.database" -}}
---
apiVersion: k8s.mariadb.com/v1alpha1
kind: Database
metadata:
  name: {{ .DatabaseName }}
  namespace: {{ .DatabaseNamespace }}
spec:
  mariaDbRef:
    name: {{ .ClusterName }}
  characterSet: utf8
  collate: utf8_general_ci
  # cleanupPolicy: Skip # Keep database even if resource is deleted (e.g. uninstall)
{{- end -}}

{{/* Template used to generate a database user in an existing mariadb cluster
Parameters :
- .DatabaseNamespace : Database namespace
- .DatabaseUser : Database user
- .ClusterName : MariaDB cluster name
*/}}
{{- define "common.mariadb.user" -}}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ .DatabaseUser }}-mariadb-creds
  namespace: {{ .DatabaseNamespace }}
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: password
    secret-generator.v1.mittwald.de/length: "32"
    secret-generator.v1.mittwald.de/encoding: hex
type: Opaque
data:
  username: {{ printf .DatabaseUser | b64enc | quote }}
---
apiVersion: k8s.mariadb.com/v1alpha1
kind: User
metadata:
  name: {{ .DatabaseUser }}
  namespace: {{ .DatabaseNamespace }}
spec:
  mariaDbRef:
    name: {{ .ClusterName }}
  passwordSecretKeyRef:
    name: {{ .DatabaseUser }}-mariadb-password
    key: password
  maxUserConnections: 20
  host: "%"
  cleanupPolicy: Delete
{{- end -}}


{{/* Template used to generate a database user in an existing mariadb cluster
Parameters :
- .DatabaseNamespace : Database namespace
- .DatabaseName : Database name
- .DatabaseUser : Database user
- .ClusterName : MariaDB cluster name
*/}}
{{- define "common.mariadb.grantall" -}}
---
apiVersion: k8s.mariadb.com/v1alpha1
kind: Grant
metadata:
  name: "grant-{{ .DatabaseUser }}-on-{{ .DatabaseName }}-mariadb"
  namespace: {{ .DatabaseNamespace }}
spec:
  mariaDbRef:
    name: {{ .ClusterName }}
  privileges:
    - "ALL PRIVILEGES"
  database: {{ .DatabaseName }}
  # table: "*"
  host: "%"
  username: {{ .DatabaseUser }}
  grantOption: false
  # cleanupPolicy: Delete
  requeueInterval: 30s
  retryInterval: 5s
{{- end -}}