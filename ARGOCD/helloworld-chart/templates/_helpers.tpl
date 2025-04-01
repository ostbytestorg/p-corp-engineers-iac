{{/*
Return the fully qualified name.
*/}}
{{- define "helloworld.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the chart name.
*/}}
{{- define "helloworld.name" -}}
{{- .Chart.Name -}}
{{- end -}}