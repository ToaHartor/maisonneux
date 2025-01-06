{{/*
Expand the name of the chart.
*/}}
{{- define "authentik-application.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "authentik-application.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "authentik-application.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "authentik-application.labels" -}}
helm.sh/chart: {{ include "authentik-application.chart" . }}
{{ include "authentik-application.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "authentik-application.selectorLabels" -}}
app.kubernetes.io/name: {{ include "authentik-application.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "authentik-application.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "authentik-application.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
needs argument:
  root: $.Values
  name: 
  default:
  overwrite:
*/}}
{{- define "authentik-application.staticValue" -}}
{{- $ := get . "root" }}
{{- $secretName := $.Values.secret.name | default (include "authentik-application.fullname" $) }}
{{- $secretObj := (lookup "v1" "Secret" $.Release.Namespace $secretName) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
{{- $valueCoded := (get $secretData .name) | default (.default | b64enc) }}
{{- .overwrite | default ($valueCoded | b64dec) }}
{{- end }}
