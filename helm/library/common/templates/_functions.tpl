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