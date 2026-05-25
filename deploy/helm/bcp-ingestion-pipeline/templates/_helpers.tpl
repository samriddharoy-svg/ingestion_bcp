{{- define "bcp-ingestion-pipeline.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bcp-ingestion-pipeline.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "bcp-ingestion-pipeline.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "bcp-ingestion-pipeline.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "bcp-ingestion-pipeline.labels" -}}
helm.sh/chart: {{ include "bcp-ingestion-pipeline.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{ include "bcp-ingestion-pipeline.selectorLabels" . }}
{{- end -}}

{{- define "bcp-ingestion-pipeline.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bcp-ingestion-pipeline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "bcp-ingestion-pipeline.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "bcp-ingestion-pipeline.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "bcp-ingestion-pipeline.secretName" -}}
{{- if .Values.existingSecretName -}}
{{- .Values.existingSecretName -}}
{{- else -}}
{{- include "bcp-ingestion-pipeline.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "bcp-ingestion-pipeline.secretStoreName" -}}
{{- if .Values.externalSecret.secretStoreRef.name -}}
{{- .Values.externalSecret.secretStoreRef.name -}}
{{- else -}}
{{- printf "%s-store" (include "bcp-ingestion-pipeline.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Renders the env namespace (configmap + secret) plus optional per-job extras.
Used inside both CronJob and Job templates.
*/}}
{{- define "bcp-ingestion-pipeline.envFrom" -}}
- configMapRef:
    name: {{ include "bcp-ingestion-pipeline.fullname" . }}
{{- if or .Values.externalSecret.enabled .Values.existingSecretName }}
- secretRef:
    name: {{ include "bcp-ingestion-pipeline.secretName" . }}
{{- end }}
{{- end -}}
