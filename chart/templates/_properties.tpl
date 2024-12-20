{{/*
Licensed to the Apache Software Foundation (ASF) under one or more
contributor license agreements.  See the NOTICE file distributed with
this work for additional information regarding copyright ownership.
The ASF licenses this file to You under the Apache License, Version 2.0
(the "License"); you may not use this file except in compliance with
the License.  You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/ -}}

{{/*
The Apache licence header
*/}}
{{- define "kafka.apache.licence" -}}
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

{{- end }}


{{/*
============================================================
Format the property value, particularly integers and lists
============================================================
*/}}
{{- define "kafka.property.value" }}
{{- if not (kindIs "map" . ) }}
{{- if and (kindIs "float64" . ) (eq (floor .) . ) }}
{{- printf "%d" (int .) }}
{{- else if kindIs "slice" . }}
{{- printf "%v" (first .) }}
{{- range (rest .) }}
{{- printf ",%v" . }}
{{- end }}
{{- else }}
{{- printf "%v" . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
============================================================
Iterate through a map outputting in properties format
============================================================
*/}}
{{- define "kafka.properties.iterate" }}
{{- range $key, $val := $.props }}
{{- if not (kindIs "map" $val) }}
{{- if eq $key "_" }}
{{- printf "%s=%s" $.name (include "kafka.property.value" $val) }}
{{- else }}
{{- printf "%s.%s=%s" $.name $key (include "kafka.property.value" $val) }}
{{- end }}
{{ else }}
{{- include "kafka.properties.iterate" (dict "name" (printf "%s.%s" $.name $key) "props" $val ) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
============================================================
Format properties from values
============================================================
*/}}
{{- define "kafka.properties" }}
{{- "# Properties from values" }}
{{ if kindIs "map" . }}
{{- range $key, $val := . }}
{{- if not (kindIs "map" $val) }}
{{- printf "%s=%s" $key (include "kafka.property.value" $val) }}
{{ else }}
{{- include "kafka.properties.iterate" (dict "name" $key "props" $val ) }}
{{- end }}
{{- end }}
{{- else }}
{{- "# No properties in values" }}
{{ "" }}
{{- end }}
{{- end }}

{{/*
============================================================
Generate a cluster id, if not specified
The cluster identifier must be a base64 encoded UUID with 
padding removed and '/' replaced by '_' and '+' replaced by '-'.
============================================================
*/}}
{{- define "kafka.clusterid" }}
{{- $configmap := (lookup "v1" "ConfigMap" (include "kafka.namespace" .) (printf "%s-settings" (include "kafka.fullname" .)) ) }}
{{- with $configmap }}
{{- $_ := set $.Values "clusterId" .data.clusterid }}
{{- else }}
{{- if not .Values.clusterId }}
{{- $_ := set $.Values "clusterId" (randBytes 16 | trimAll "=" | replace "/" "_" | replace "+" "-") }}
{{- end }}
{{- end }}
{{- .Values.clusterId }}
{{- end }}

{{/*
============================================================
Properties file for the controllers
============================================================
*/}}
{{- define "kafka.controller.properties" }}
{{- $ns := include "kafka.namespace" .root }}
{{- $serviceName := include "kafka.controller.service" .root }}
{{- $ctr := include "kafka.controller" .root }}
{{- $nodeId := add (int .root.Values.controller.baseId) .instance }}
{{- include "kafka.apache.licence" .root }}

############################# Server Basics #############################

# The role of this server. Setting this puts us in KRaft mode
process.roles=controller

# The node id associated with this instance's roles
node.id={{ $nodeId }}

# The connect string for the controller quorum
controller.quorum.voters={{ include "kafka.controller.quorum.voters" .root }}

listeners={{ printf "CONTROLLER://%s-%d.%s.%s.svc.cluster.local:%d" $ctr .instance $serviceName $ns (int .root.Values.controller.port) }}

controller.listener.names=CONTROLLER

log.dirs=/mnt/kafka/controllers/{{ $nodeId }}

{{ include "kafka.properties" (merge .root.Values.properties .root.Values.controller.properties) }}

{{- end }}

{{/*
============================================================
Properties file for the brokers
============================================================
*/}}
{{- define "kafka.broker.properties" }}
{{- $ns := include "kafka.namespace" .root }}
{{- $serviceName := include "kafka.broker.service" .root }}
{{- $bkr := include "kafka.fullname" .root }}
{{- $nodeId := add (int .root.Values.broker.baseId) .instance }}
{{- include "kafka.apache.licence" .root }}

############################# Server Basics #############################

# The role of this server. Setting this puts us in KRaft mode
process.roles=broker

# The node id associated with this instance's roles
node.id={{ $nodeId }}

# The connect string for the controller quorum
controller.quorum.voters={{ include "kafka.controller.quorum.voters" .root }}

listeners={{ printf "PLAINTEXT://%s-%d.%s.%s.svc.cluster.local:%d" $bkr .instance $serviceName $ns (int .root.Values.broker.port) }}

controller.listener.names=CONTROLLER

log.dirs=/mnt/kafka/brokers/{{ $nodeId }}

{{ include "kafka.properties" (merge .root.Values.properties .root.Values.broker.properties) }}

{{- end }}


{{/*
============================================================
Properties file for log4j
============================================================
*/}}
{{- define "kafka.log4j.properties" }}
{{- include "kafka.apache.licence" . }}

log4j.rootLogger={{ .Values.logging.rootLogger }}
{{ range $apndr,$conf := .Values.logging.appenders }}
log4j.appender.{{ $apndr }}={{ $conf.type }}
log4j.appender.{{ $apndr }}.DatePattern={{ $.Values.logging.datePattern }}
{{- with get $conf "file" }}
log4j.appender.{{ $apndr }}.File={{ . }}
{{- end }}
log4j.appender.{{ $apndr }}.layout={{ $.Values.logging.appenderLayout.type }}
log4j.appender.{{ $apndr }}.layout.ConversionPattern={{ $.Values.logging.appenderLayout.conversionPattern }}
{{ end }}
log4j.logger.org.apache.kafka={{ .Values.brokerLogLevel }}

log4j.logger.kafka.request.logger={{ .Values.logging.requestLogLevel }}, requestAppender
log4j.additivity.kafka.request.logger=false
{{- if or (eq .Values.logging.requestChannelLogLevel "DEBUG") (eq .Values.logging.requestChannelLogLevel "TRACE") }}

# Change to DEBUG or TRACE to enable request logging
log4j.logger.kafka.network.Processor={{ .Values.logging.requestChannelLogLevel }}, requestAppender
log4j.logger.kafka.server.KafkaApis={{ .Values.logging.requestChannelLogLevel }}, requestAppender
log4j.additivity.kafka.server.KafkaApis=false
{{- end }}

log4j.logger.kafka.network.RequestChannel$={{ .Values.logging.requestChannelLogLevel }}, requestAppender
log4j.additivity.kafka.network.RequestChannel$=false

log4j.logger.org.apache.kafka.controller={{ .Values.logging.controllerLogLevel }}, controllerAppender
log4j.additivity.org.apache.kafka.controller=false

log4j.logger.kafka.log.LogCleaner={{ .Values.logging.logCleanerLogLevel }}, cleanerAppender
log4j.additivity.kafka.log.LogCleaner=false

log4j.logger.state.change.logger={{ .Values.logging.stateChangeLogLevel }}, stateChangeAppender
log4j.additivity.state.change.logger=false

log4j.logger.kafka.authorizer.logger={{ .Values.logging.authorizerLogLevel }}, authorizerAppender
log4j.additivity.kafka.authorizer.logger=false

{{- end }}


{{/*
============================================================
Properties file for log4j for tools (i.e. storage tool)
============================================================
*/}}
{{- define "kafka.tools-log4j.properties" }}
{{- include "kafka.apache.licence" . }}

log4j.rootLogger={{ .Values.toolLogging.rootLogger }}
{{ range $apndr,$conf := .Values.toolLogging.appenders }}
log4j.appender.{{ $apndr }}={{ $conf.type }}
{{- with get $conf "file" }}
log4j.appender.{{ $apndr }}.File={{ . }}
{{- end }}
log4j.appender.{{ $apndr }}.layout={{ $.Values.toolLogging.appenderLayout.type }}
log4j.appender.{{ $apndr }}.layout.ConversionPattern={{ $.Values.toolLogging.appenderLayout.conversionPattern }}
{{- with get $conf "target" }}
log4j.appender.{{ $apndr }}.Target={{ . }}
{{- end }}
{{ end }}

{{- end }}
