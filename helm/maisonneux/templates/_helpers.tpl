{{/* Function to generate a secret if not present
It must be called with a dict containing the following attributes :
- global values : .Values
- namespace : .SecretNs
- secret name : .SecretName
- secret key : .SecretKey
- secret length : .SecretLength (optional, only if length must be specified)
*/}}
{{- define "generate-secret" -}}
  {{/*First of all check if we already generated the same secret, so that we don't have to generate it again*/}}
  {{- $cached_secret_name := printf "cached-%s-%s-%s" .SecretNs .SecretName .SecretKey -}}
  {{- if (hasKey .Values $cached_secret_name) -}}
    {{- print (get .Values $cached_secret_name) -}}
  {{- else -}}
    {{/*# Then, we can check in a running cluster */}}
    {{- $secret := lookup "v1" "Secret" .SecretNs .SecretName | default dict -}}
    {{- if $secret -}}
      {{- print (get $secret.data .SecretKey) }}
    {{- else -}}
      {{/* Secret does not exist, generate */}}
      {{- $secret_length := .SecretLength | default 64 -}}
      {{- $new_secret := randAlphaNum $secret_length | b64enc | quote -}}
      {{/* Set new secret as already generated */}}
      {{- $_ := set .Values $cached_secret_name $new_secret -}}
      {{- print $new_secret -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{/* Function to create a mongodb user with admin access on the database
Must be called with a dict with the following attributes :
- database name : .Database
- user name : .Name
*/}}
{{- define "create-mongodb-user" -}}
- name: {{ .Name }}
  db: {{ .Database }}
  passwordSecretRef:
    name: "mongodb-{{ .Name }}-secret"
    key: password
  roles:
    - name: dbAdmin
      db: {{ .Database }}
  scramCredentialsSecretName: "mongodb-{{ .Name }}"
{{- end -}}
