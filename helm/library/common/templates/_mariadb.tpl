{{/* Template used to generate a database in an existing mariadb cluster
Parameters :
- .DatabaseNamespace : Database namespace
- .DatabaseName : Database name
- .ClusterName : MariaDB cluster name
*/}}
{{- define "common.mariadb.database" -}}
apiVersion: k8s.mariadb.com/v1alpha1
kind: Database
metadata:
  name: {{ .DatabaseName | replace "_" "-" }}
  namespace: {{ .DatabaseNamespace }}
spec:
  name: {{ .DatabaseName }} # Set again database name (for names which have special characters forbidden in metadata.name)
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
{{- $secretName := include "common.db.secret-name" (dict "DatabaseUser" .DatabaseUser) }}
{{- include "common.secret.creds" (dict "Username" .DatabaseUser "SecretName" $secretName "SecretNamespace" .DatabaseNamespace) }}
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
    name: {{ $secretName }}
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
apiVersion: k8s.mariadb.com/v1alpha1
kind: Grant
metadata:
  name: "grant-{{ .DatabaseUser }}-on-{{ .DatabaseName | replace "_" "-" }}-mariadb"
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