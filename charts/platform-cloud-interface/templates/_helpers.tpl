{{- define "pci.apiName" -}}{{ .Values.name }}-api{{- end }}
{{- define "pci.webName" -}}{{ .Values.name }}-web{{- end }}

{{- define "pci.image" -}}
{{ .Values.image.repository }}/{{ .component.name }}:{{ .component.tag | default .Values.image.tag }}
{{- end }}

{{/*
An env var taken either from a plain value or a secret reference.
Arguments: dict "name" <env var> "value" <value> "secret" <{name, key}>
*/}}
{{- define "pci.env" -}}
- name: {{ .name }}
{{- if .secret }}
  valueFrom:
    secretKeyRef:
      name: {{ .secret.name }}
      key: {{ .secret.key }}
{{- else }}
  value: {{ .value | default "" | quote }}
{{- end }}
{{- end }}

{{- define "pci.appKey" -}}
{{- if not (or .Values.config.appkey .Values.config.appkey_secret) -}}
{{- fail "config.appkey or config.appkey_secret is required" -}}
{{- end -}}
{{ include "pci.env" (dict "name" "APP_KEY" "value" .Values.config.appkey "secret" .Values.config.appkey_secret) }}
{{- end }}

{{- define "pci.oauthSecret" -}}
{{- $c := .Values.config.oauth_client -}}
{{- if not (or $c.secret $c.secret_secret) -}}
{{- fail "config.oauth_client.secret or config.oauth_client.secret_secret is required" -}}
{{- end -}}
{{ include "pci.env" (dict "name" .envName "value" $c.secret "secret" $c.secret_secret) }}
{{- end }}

{{- define "pci.cacheEnv" -}}
- name: CACHE_DRIVER
  value: {{ .drivers.cache | quote }}
- name: SESSION_DRIVER
  value: {{ .drivers.session | quote }}
{{- with .config.redis }}
{{- if .host }}
- name: REDIS_HOST
  value: {{ .host | quote }}
- name: REDIS_PORT
  value: {{ .port | default 6379 | quote }}
{{- end }}
{{- end }}
{{- with .config.memcached }}
{{- if .host }}
- name: MEMCACHED_HOST
  value: {{ .host | quote }}
- name: MEMCACHED_PORT
  value: {{ .port | default 11211 | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Environment of the api container, shared with the migrations job
*/}}
{{- define "pci.apiEnv" -}}
{{- $c := .Values.config -}}
- name: APP_ENV
  value: {{ $c.appenv | quote }}
- name: APP_DEBUG
  value: {{ .Values.api.debug | quote }}
{{ include "pci.appKey" . }}
- name: APP_LOCALE
  value: {{ $c.locale | quote }}
- name: APP_FALLBACK_LOCALE
  value: "en"
- name: DB_CONNECTION
  value: mysql
- name: DB_HOST
  value: {{ $c.db.host | quote }}
- name: DB_PORT
  value: {{ $c.db.port | quote }}
- name: DB_DATABASE
  value: {{ $c.db.database | quote }}
- name: DB_USERNAME
  value: {{ $c.db.username | quote }}
{{ include "pci.env" (dict "name" "DB_PASSWORD" "value" $c.db.password "secret" $c.db.password_secret) }}
- name: DOCKERIZE_WAIT_FOR_mysql
  value: "tcp://{{ $c.db.host }}:{{ $c.db.port }}"
- name: DOCKERIZE_TIMEOUT
  value: {{ .Values.api.params.dependency_wait_timeout | quote }}
{{ include "pci.cacheEnv" (dict "drivers" .Values.api.drivers "config" $c) }}
- name: CLOUD_DEPLOYMENTS_DOMAIN
  value: {{ $c.domain | quote }}
- name: CLOUD_DEPLOYMENTS_API_DOMAIN
  value: {{ $c.api_domain | quote }}
- name: CLOUD_DEFAULT_TIER
  value: {{ $c.default_tier | quote }}
{{- with $c.deployments }}
- name: CLOUD_DEFAULT_DB_HOST
  value: {{ .db_host | default $c.db.host | quote }}
{{- if .db_host_replica }}
- name: CLOUD_DEFAULT_DB_HOST_REPLICA
  value: {{ .db_host_replica | quote }}
{{- end }}
{{- if .db_prefix }}
- name: CLOUD_DEPLOYMENTS_DB_PREFIX
  value: {{ .db_prefix | quote }}
{{- end }}
{{- else }}
- name: CLOUD_DEFAULT_DB_HOST
  value: {{ $c.db.host | quote }}
{{- end }}
- name: DOCKERINIT_CLOUDAPI_CLIENT
  value: {{ $c.oauth_client.id | quote }}
{{ include "pci.oauthSecret" (dict "envName" "DOCKERINIT_CLOUDAPI_SECRET" "Values" .Values) }}
{{- with $c.amqp }}
{{- if .host }}
- name: CLOUD_AMQP_URL
  value: {{ .host | quote }}
- name: CLOUD_AMQP_PORT
  value: {{ .port | default 5672 | quote }}
- name: CLOUD_AMQP_USERNAME
  value: {{ .username | quote }}
{{ include "pci.env" (dict "name" "CLOUD_AMQP_PASSWORD" "value" .password "secret" .password_secret) }}
{{- end }}
{{- end }}
{{- with $c.chargebee }}
{{- if .subdomain }}
- name: CLOUD_CHARGEBEE_SUBDOMAIN
  value: {{ .subdomain | quote }}
{{ include "pci.env" (dict "name" "CLOUD_CHARGEBEE_APIKEY" "value" .apikey "secret" .apikey_secret) }}
{{- end }}
{{- end }}
{{- with $c.sentry.dsn }}
- name: SENTRY_DSN
  value: {{ . | quote }}
{{- end }}
- name: PHP_EXEC_TIME_LIMIT
  value: {{ .Values.api.params.php_exec_time_limit | quote }}
{{- with .Values.api.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "pci.webEnv" -}}
{{- $c := .Values.config -}}
- name: APP_ENV
  value: {{ $c.appenv | quote }}
- name: APP_DEBUG
  value: {{ .Values.web.debug | quote }}
{{ include "pci.appKey" . }}
- name: APP_LOCALE
  value: {{ $c.locale | quote }}
- name: APP_FALLBACK_LOCALE
  value: "en"
{{ include "pci.cacheEnv" (dict "drivers" .Values.web.drivers "config" $c) }}
- name: CLOUDAPI_URL
  value: "http://{{ include "pci.apiName" . }}"
- name: CLOUDAPI_DOMAIN
  value: {{ $c.domain | quote }}
- name: CLOUDAPI_CLIENT
  value: {{ $c.oauth_client.id | quote }}
{{ include "pci.oauthSecret" (dict "envName" "CLOUDAPI_SECRET" "Values" .Values) }}
{{- with $c.analytics }}
- name: USH_ANALYTICS_PREFIX
  value: {{ .ush_analytics_prefix | default "" | quote }}
- name: GTM_CONTAINER_ID
  value: {{ .gtm_container_id | default "" | quote }}
- name: COOKIEBOT_ID
  value: {{ .cookiebot_id | default "" | quote }}
- name: CLOUDAPI_INTERCOM_APPID
  value: {{ .intercom_appid | default "" | quote }}
{{- end }}
{{- with $c.sentry.dsn }}
- name: SENTRY_DSN
  value: {{ . | quote }}
{{- end }}
{{- with .Values.web.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "pci.ingress" -}}
{{- $ing := .component.ingress -}}
{{- if $ing.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .name }}
  labels:
    app: platform-cloud-interface
    service: {{ .service }}
  annotations:
{{- with $ing.annotations }}
{{ toYaml . | indent 4 }}
{{- end }}
spec:
{{- with $ing.className }}
  ingressClassName: {{ . }}
{{- end }}
  rules:
{{- range (concat (list (required (printf "%s.ingress.host is required" .service) $ing.host)) ($ing.aliases | default list)) }}
  - host: {{ . | quote }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ $.name }}
            port:
              name: http
{{- end }}
{{- with $ing.tls }}
  tls:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
