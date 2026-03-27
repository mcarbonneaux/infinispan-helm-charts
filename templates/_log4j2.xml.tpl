{{- define "log4j2.xml" -}}
<Configuration name="InfinispanServerConfig" monitorInterval="60" shutdownHook="disable">
  <Properties>
    <Property name="path">${sys:infinispan.server.log.path}</Property>
    <Property name="accessLogPattern">%X{address} %X{user} [%d{dd/MMM/yyyy:HH:mm:ss Z}] &quot;%X{method} %m %X{protocol}&quot; %X{status} %X{requestSize} %X{responseSize} %X{duration}%n</Property>
  </Properties>
  <Appenders>
    <!-- Colored output on the console -->
    <Console name="STDOUT">
      <PatternLayout pattern="%highlight{%d{yyyy-MM-dd HH:mm:ss,SSS} %-5p (%t) [%c] %m%throwable}{INFO=normal, DEBUG=normal, TRACE=normal}%n"/>
    </Console>

    <!-- JSON output on the console for log aggregation (ELK, Loki, etc.) -->
    <Console name="JSON-STDOUT">
      <JsonLayout compact="true" eventEol="true" stacktraceAsString="true">
        <KeyValuePair key="time"      value="$${date:yyyy-MM-dd'T'HH:mm:ss.SSSZ}" />
        <KeyValuePair key="service"   value="infinispan" />
        <KeyValuePair key="namespace" value="$${env:POD_NAMESPACE:-unknown}" />
        <KeyValuePair key="pod"       value="$${env:POD_NAME:-unknown}" />
      </JsonLayout>
    </Console>

    <!-- ECS (Elastic Common Schema) output on the console -->
    <!-- Note: This uses JsonLayout (log4j-core) to approximate ECS format.
         For full ECS support, add log4j-layout-template-json.jar to libraries. -->
    <Console name="ECS-STDOUT">
      <JsonLayout compact="true" eventEol="true" stacktraceAsString="true" properties="true" includeStacktrace="true">
        <KeyValuePair key="@timestamp"         value="$${date:yyyy-MM-dd'T'HH:mm:ss.SSS'Z'}{UTC}" />
        <KeyValuePair key="ecs.version"        value="1.2.0" />
        <KeyValuePair key="log.level"          value="$${level}" />
        <KeyValuePair key="message"            value="$${message}" />
        <KeyValuePair key="process.thread.name" value="$${thread}" />
        <KeyValuePair key="log.logger"         value="$${logger}" />
        <KeyValuePair key="service.name"       value="infinispan" />
        <KeyValuePair key="service.type"       value="cache" />
        <KeyValuePair key="host.name"          value="$${env:POD_NAME:-unknown}" />
        <KeyValuePair key="labels.namespace"   value="$${env:POD_NAMESPACE:-unknown}" />
        <KeyValuePair key="labels.pod"         value="$${env:POD_NAME:-unknown}" />
        <KeyValuePair key="labels.cluster"     value="$${sys:infinispan.cluster.name:-cluster}" />
      </JsonLayout>
    </Console>

    <!-- Rolling file -->
    <RollingFile name="FILE" createOnDemand="true"
                 fileName="${path}/server.log"
                 filePattern="${path}/server.log.%d{yyyy-MM-dd}-%i">
      <Policies>
        <OnStartupTriggeringPolicy />
        <SizeBasedTriggeringPolicy size="100 MB" />
        <TimeBasedTriggeringPolicy />
      </Policies>
      <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss,SSS} %-5p (%t) [%c] %m%throwable%n"/>
    </RollingFile>

    <!-- Rolling file -->
    <RollingFile name="AUDIT-FILE" createOnDemand="true"
                 fileName="${path}/audit.log"
                 filePattern="${path}/audit.log.%d{yyyy-MM-dd}-%i">
      <Policies>
        <OnStartupTriggeringPolicy />
        <SizeBasedTriggeringPolicy size="100 MB" />
        <TimeBasedTriggeringPolicy />
      </Policies>
      <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss,SSS} %m%n"/>
    </RollingFile>

    <!-- Rolling JSON file, disabled by default -->
    <RollingFile name="JSON-FILE" createOnDemand="true"
                 fileName="${path}/server.log.json"
                 filePattern="${path}/server.log.json.%d{yyyy-MM-dd}-%i">
      <Policies>
        <OnStartupTriggeringPolicy />
        <SizeBasedTriggeringPolicy size="100 MB" />
        <TimeBasedTriggeringPolicy />
      </Policies>
      <JsonLayout compact="true" eventEol="true" stacktraceAsString="true">
        <KeyValuePair key="time" value="$${date:yyyy-MM-dd'T'HH:mm:ss.SSSZ}" />
      </JsonLayout>
    </RollingFile>

    <!-- Rolling HotRod access log, disabled by default -->
    <RollingFile name="HR-ACCESS-FILE" createOnDemand="true"
                 fileName="${path}/hotrod-access.log"
                 filePattern="${path}/hotrod-access.log.%i">
      <Policies>
        <SizeBasedTriggeringPolicy size="100 MB" />
      </Policies>
      <PatternLayout pattern="${accessLogPattern}"/>
    </RollingFile>
    <!-- Rolling REST access log, disabled by default -->
    <RollingFile name="REST-ACCESS-FILE" createOnDemand="true"
                 fileName="${path}/rest-access.log"
                 filePattern="${path}/rest-access.log.%i">
      <Policies>
        <SizeBasedTriggeringPolicy size="100 MB" />
      </Policies>
      <PatternLayout pattern="${accessLogPattern}"/>
    </RollingFile>
  </Appenders>

  <Loggers>
    <Root level="INFO">
      {{- if .Values.deploy.logging.console.json }}
      {{- /* Backward compatibility: json: true overrides format */ -}}
      <AppenderRef ref="JSON-STDOUT"/>
      {{- else if eq .Values.deploy.logging.console.format "ecs" }}
      <AppenderRef ref="ECS-STDOUT"/>
      {{- else if eq .Values.deploy.logging.console.format "json" }}
      <AppenderRef ref="JSON-STDOUT"/>
      {{- else }}
      {{- /* Default: colored format */ -}}
      <AppenderRef ref="STDOUT"/>
      {{- end }}

      <!-- Uncomment just one of the two lines bellow to use alternatively JSON logging or plain-text logging to file-->
      <AppenderRef ref="FILE"/>
<!--      <AppenderRef ref="JSON-FILE"/>-->
    </Root>

    <!-- Set to INFO to enable audit logging -->
    <Logger name="org.infinispan.AUDIT" additivity="false" level="ERROR">
      <AppenderRef ref="AUDIT-FILE"/>
    </Logger>

    <!-- Set to TRACE to enable access logging for Hot Rod requests -->
    <Logger name="org.infinispan.HOTROD_ACCESS_LOG" additivity="false" level="INFO">
      <AppenderRef ref="HR-ACCESS-FILE"/>
    </Logger>

    <!-- Set to TRACE to enable access logging for REST requests -->
    <Logger name="org.infinispan.REST_ACCESS_LOG" additivity="false" level="INFO">
      <AppenderRef ref="REST-ACCESS-FILE"/>
    </Logger>

    {{- if .Values.deploy.logging.categories}}
    {{- range .Values.deploy.logging.categories }}
    <Logger name="{{ .category }}" level="{{ .level | upper }}" />
    {{- end }}
    {{- end }}

  </Loggers>
</Configuration>
{{- end }}