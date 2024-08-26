{{/*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return the proper KeyDB Master fullname
*/}}
{{- define "keydb.master.fullname" -}}
{{- printf "%s-master" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the proper KeyDB Replicas fullname
*/}}
{{- define "keydb.replica.fullname" -}}
{{- printf "%s-replica" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the proper KeyDB image name
*/}}
{{- define "keydb.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper KeyDB metrics exporter name
*/}}
{{- define "keydb.metrics.image" -}}
{{- include "common.images.image" ( dict "imageRoot" .Values.metrics.image "global" .Values.global ) -}}
{{- end -}}


{{/*
Return the proper image name (for the init container volume-permissions image)
*/}}
{{- define "keydb.volumePermissions.image" -}}
{{- include "common.images.image" ( dict "imageRoot" .Values.volumePermissions.image "global" .Values.global ) -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "keydb.imagePullSecrets" -}}
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.image  .Values.metrics.image .Values.volumePermissions.image) "context" $) -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "keydb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the name of the configmap with KeyDB master configuration
*/}}
{{- define "keydb.master.configmapName" -}}
{{- if .Values.master.existingConfigmap -}}
    {{- print (tpl .Values.master.existingConfigmap $) -}}
{{- else -}}
    {{- printf "%s-config" (include "keydb.master.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the configmap with KeyDB replica configuration
*/}}
{{- define "keydb.replica.configmapName" -}}
{{- if .Values.replica.existingConfigmap -}}
    {{- print (tpl .Values.replica.existingConfigmap $) -}}
{{- else -}}
    {{- printf "%s-config" (include "keydb.replica.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the secret with KeyDB credentials
*/}}
{{- define "keydb.secretName" -}}
{{- if .Values.auth.existingSecret -}}
    {{- print (tpl .Values.auth.existingSecret $) -}}
{{- else -}}
    {{- print (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Get the password key to be retrieved from KeyDB secret
*/}}
{{- define "keydb.secretPasswordKey" -}}
{{- if and .Values.auth.existingSecret .Values.auth.existingSecretPasswordKey -}}
    {{- print (tpl .Values.auth.existingSecretPasswordKey $) -}}
{{- else -}}
    {{- print "keydb-password" -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the secret containing the TLS certificates for KeyDB master nodes
*/}}
{{- define "keydb.tls.master.secretName" -}}
{{- if or .Values.tls.autoGenerated.enabled (and (not (empty .Values.tls.master.cert)) (not (empty .Values.tls.master.key))) -}}
    {{- printf "%s-crt" (include "keydb.master.fullname" .) -}}
{{- else -}}
    {{- required "An existing secret name must be provided with TLS certs for KeyDB master if cert and key are not provided!" (tpl .Values.tls.master.existingSecret .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the secret containing the TLS certificates for KeyDB replica nodes
*/}}
{{- define "keydb.tls.replica.secretName" -}}
{{- if or .Values.tls.autoGenerated.enabled (and (not (empty .Values.tls.replica.cert)) (not (empty .Values.tls.replica.key))) -}}
    {{- printf "%s-crt" (include "keydb.replica.fullname" .) -}}
{{- else -}}
    {{- required "An existing secret name must be provided with TLS certs for KeyDB replica if cert and key are not provided!" (tpl .Values.tls.replica.existingSecret .) -}}
{{- end -}}
{{- end -}}

{{/*
Compile all warnings into a single message.
*/}}
{{- define "keydb.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "keydb.validateValues.architecture" .) -}}
{{- $messages := append $messages (include "keydb.validateValues.master.replicaCount" .) -}}
{{- $messages := append $messages (include "keydb.validateValues.replica.replicaCount" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message -}}
{{- end -}}
{{- end -}}

{{/*
Validate values of KeyDB - must provide a valid architecture
*/}}
{{- define "keydb.validateValues.architecture" -}}
{{- if and (ne .Values.architecture "standalone") (ne .Values.architecture "replication") -}}
architecture
    Invalid architecture selected. Valid values are "standalone" and
    "replication". Please set a valid architecture (--set architecture="xxxx")
{{- end -}}
{{- end -}}

{{/*
Validate values of KeyDB - number of Master replicas
*/}}
{{- define "keydb.validateValues.master.replicaCount" -}}
{{- $masterReplicaCount := int .Values.master.replicaCount }}
{{- $replicaReplicaCount := int .Values.replica.replicaCount }}
{{- if and .Values.master.persistence.enabled .Values.master.persistence.existingClaim (gt $masterReplicaCount 1) -}}
master.replicaCount
    A single existing PVC cannot be shared between multiple Master replicas.
    Please set a valid number of replicas (--set master.replicaCount=1), disable persistence
    (--set master.persistence.enabled=false) or rely on dynamic provisioning via Persistent
    Volume Claims (--set master.persistence.existingClaim="").
{{- end -}}
{{- if and (eq .Values.architecture "replication") (gt $masterReplicaCount 1) (gt $replicaReplicaCount 0) (not .Values.replica.activeReplica) -}}
master.replicaCount
    Multipe Master replicas are only supported when replicas are configured as active replicas.
    Please set a valid number of replicas (--set master.replicaCount=1), set replicas as active
    (--set replica.activeReplica=true) or disable replication (--set architecture="standalone").
{{- end -}}
{{- end -}}

{{/*
Validate values of KeyDB - number of Replicas
*/}}
{{- define "keydb.validateValues.replica.replicaCount" -}}
{{- $replicaReplicaCount := int .Values.replica.replicaCount }}
{{- if and .Values.replica.persistence.enabled .Values.replica.persistence.existingClaim (or (gt $replicaReplicaCount 1) .Values.replica.autoscaling.hpa.enabled) -}}
replica.replicaCount
    A single existing PVC cannot be shared between multiple Replicas.
    Please set a valid number of replicas (--set replica.replicaCount=1),
    disable HPA (--set replica.autoscaling.hpa.enabled=false), disable persistence
    (--set replica.persistence.enabled=false) or rely on dynamic provisioning via Persistent
    Volume Claims (--set replica.persistence.existingClaim="").
{{- end -}}
{{- end -}}
