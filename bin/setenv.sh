#!/bin/bash -eu

replace_in_file() {
  local _tmpFile=$(mktemp /tmp/replace.XXXXXXXXXX) || {
    echo "Failed to create temp file"
    exit 1
  }
  mv $1 ${_tmpFile}
  sed "s|$2|$3|g" ${_tmpFile} >$1
  rm ${_tmpFile}
}

[ -z "${ACCESS_LOG_ENABLED}" ] && ACCESS_LOG_ENABLED="false"
[ -z "${JMX_ENABLED}" ] && JMX_ENABLED="false"
[ -z "${JMX_RMI_REGISTRY_PORT}" ] && JMX_RMI_REGISTRY_PORT="10001"
[ -z "${JMX_RMI_SERVER_PORT}" ] && JMX_RMI_SERVER_PORT="10002"
[ -z "${JMX_RMI_SERVER_HOSTNAME}" ] && JMX_RMI_SERVER_HOSTNAME="localhost"
[ -z "${JMX_USERNAME}" ] && JMX_USERNAME="-"
[ -z "${JMX_PASSWORD}" ] && JMX_PASSWORD="-"

[ -z "${JVM_SIZE_MIN}" ] && JVM_SIZE_MIN="512m"
[ -z "${JVM_SIZE_MAX}" ] && JVM_SIZE_MAX="512m"
[ -z "${JVM_METASPACE_SIZE_MAX}" ] && JVM_METASPACE_SIZE_MAX="128m"
[ -z "${JVM_LOG_GC_ENABLED}" ] && JVM_LOG_GC_ENABLED="false"

[ -z "${HTTP_THREAD_MIN}" ] && HTTP_THREAD_MIN="10"
[ -z "${HTTP_THREAD_MAX}" ] && HTTP_THREAD_MAX="200"

[ -z "${PROXY_VHOST}" ] && PROXY_VHOST="localhost"
[ -z "${PROXY_SSL}" ] && PROXY_SSL="true"
[ -z "${PROXY_PORT}" ] && {
  case "${PROXY_SSL}" in
  true) PROXY_PORT="443" ;;
  false) PROXY_PORT="80" ;;
  *) PROXY_PORT="80" ;;
  esac
}

## Remove file comments
xmlstarlet ed -L -d "//comment()" ${INSTALL_DIR}/conf/server.xml || {
  echo "ERROR during xmlstarlet processing (xml comments removal)"
  exit 1
}

## Remove AJP connector
xmlstarlet ed -L -d '//Connector[@protocol="AJP/1.3"]' ${INSTALL_DIR}/conf/server.xml || {
  echo "ERROR during xmlstarlet processing (AJP connector removal)"
  exit 1
}

# Tomcat HTTP Thread pool configuration
xmlstarlet ed -L -s "/Server/Service/Connector" -t attr -n "maxThreads" -v "${HTTP_THREAD_MAX}" \
  -s "/Server/Service/Connector" -t attr -n "minSpareThreads" -v "${HTTP_THREAD_MIN}" \
  ${INSTALL_DIR}/conf/server.xml || {
  echo "ERROR during xmlstarlet processing (configuring threads)"
  exit 1
}

# Proxy configuration
xmlstarlet ed -L -s "/Server/Service/Connector" -t attr -n "proxyName" -v "${PROXY_VHOST}" ${INSTALL_DIR}/conf/server.xml || {
  echo "ERROR during xmlstarlet processing (adding Connector proxyName)"
  exit 1
}

if [ "${PROXY_SSL}" = "true" ]; then
  xmlstarlet ed -L -s "/Server/Service/Connector" -t attr -n "scheme" -v "https" \
    -s "/Server/Service/Connector" -t attr -n "secure" -v "false" \
    -s "/Server/Service/Connector" -t attr -n "proxyPort" -v "${PROXY_PORT}" \
    ${INSTALL_DIR}/conf/server.xml || {
    echo "ERROR during xmlstarlet processing (configuring Connector proxy ssl)"
    exit 1
  }
else
  xmlstarlet ed -L -s "/Server/Service/Connector" -t attr -n "scheme" -v "http" \
    -s "/Server/Service/Connector" -t attr -n "secure" -v "false" \
    -s "/Server/Service/Connector" -t attr -n "proxyPort" -v "${PROXY_PORT}" \
    ${INSTALL_DIR}/conf/server.xml || {
    echo "ERROR during xmlstarlet processing (configuring Connector proxy)"
    exit 1
  }
fi

# Add a new valve to replace the proxy ip by the client ip (just before the end of Host)
xmlstarlet ed -L -s "/Server/Service/Engine/Host" -t elem -n "ValveTMP" -v "" \
  -i "//ValveTMP" -t attr -n "className" -v "org.apache.catalina.valves.RemoteIpValve" \
  -i "//ValveTMP" -t attr -n "remoteIpHeader" -v "x-forwarded-for" \
  -i "//ValveTMP" -t attr -n "proxiesHeader" -v "x-forwarded-by" \
  -i "//ValveTMP" -t attr -n "protocolHeader" -v "x-forwarded-proto" \
  -r "//ValveTMP" -v Valve \
  ${INSTALL_DIR}/conf/server.xml || {
  echo "ERROR during xmlstarlet processing (adding RemoteIpValve)"
  exit 1
}

# JMX configuration
if [ "${JMX_ENABLED}" = "true" ]; then
  # insert the listener before the "Global JNDI resources" line
  xmlstarlet ed -L -i "/Server/GlobalNamingResources" -t elem -n ListenerTMP -v "" \
    -i "//ListenerTMP" -t attr -n "className" -v "org.apache.catalina.mbeans.JmxRemoteLifecycleListener" \
    -i "//ListenerTMP" -t attr -n "rmiRegistryPortPlatform" -v "${JMX_RMI_REGISTRY_PORT}" \
    -i "//ListenerTMP" -t attr -n "rmiServerPortPlatform" -v "${JMX_RMI_SERVER_PORT}" \
    -i "//ListenerTMP" -t attr -n "useLocalPorts" -v "false" \
    -r "//ListenerTMP" -v "Listener" \
    ${INSTALL_DIR}/conf/server.xml || {
    echo "ERROR during xmlstarlet processing (adding JmxRemoteLifecycleListener)"
    exit 1
  }

  CATALINA_OPTS="${CATALINA_OPTS:-} -Dcom.sun.management.jmxremote=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.ssl=false"
  CATALINA_OPTS="${CATALINA_OPTS} -Djava.rmi.server.hostname=${JMX_RMI_SERVER_HOSTNAME}"

  # Create the security files if required
  if [ "${JMX_USERNAME:-}" != "-" ]; then
    if [ "${JMX_PASSWORD:-}" = "-" ]; then
      JMX_PASSWORD="$(tr -dc '[:alnum:]' </dev/urandom | dd bs=2 count=6 2>/dev/null)"
    fi
    # /opt/cmis-server/conf/jmxremote.password
    echo "${JMX_USERNAME} ${JMX_PASSWORD}" >${INSTALL_DIR}/conf/jmxremote.password
    # /opt/cmis-server/conf/jmxremote.access
    echo "${JMX_USERNAME} readwrite" >${INSTALL_DIR}/conf/jmxremote.access

    CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.authenticate=true"
    CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.password.file=${INSTALL_DIR}/conf/jmxremote.password"
    CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.access.file=${INSTALL_DIR}/conf/jmxremote.access"
  else
    CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.authenticate=false"
  fi
fi

# Access log configuration
if [ "${ACCESS_LOG_ENABLED}" = "true" ]; then
  # Add a new valve (just before the end of Host)
  xmlstarlet ed -L -s "/Server/Service/Engine/Host" -t elem -n "ValveTMP" -v "" \
    -i "//ValveTMP" -t attr -n "className" -v "org.apache.catalina.valves.AccessLogValve" \
    -i "//ValveTMP" -t attr -n "pattern" -v "combined" \
    -i "//ValveTMP" -t attr -n "directory" -v "logs" \
    -i "//ValveTMP" -t attr -n "prefix" -v "access" \
    -i "//ValveTMP" -t attr -n "suffix" -v ".log" \
    -i "//ValveTMP" -t attr -n "rotatable" -v "true" \
    -i "//ValveTMP" -t attr -n "renameOnRotate" -v "true" \
    -i "//ValveTMP" -t attr -n "fileDateFormat" -v ".yyyy-MM-dd" \
    -r "//ValveTMP" -v Valve \
    ${INSTALL_DIR}/conf/server.xml || {
    echo "ERROR during xmlstarlet processing (adding AccessLogValve)"
    exit 1
  }
fi

# -----------------------------------------------------------------------------
# LOG GC configuration
# -----------------------------------------------------------------------------
if [ "${JVM_LOG_GC_ENABLED}" = "true" ]; then
  LOG_DIR=${INSTALL_DIR}/logs
  # -XX:+PrintGCDateStamps : print the absolute timestamp in the log statement (i.e. “2014-11-18T16:39:25.303-0800”)
  # -XX:+PrintGCTimeStamps : print the time when the GC event started, relative to the JVM startup time (unit: seconds)
  # -XX:+PrintGCDetails    : print the details of how much memory is reclaimed in each generation
  JVM_LOG_GC_OPTS="-XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
  echo "Enabling JVM GC logs with [${JVM_LOG_GC_OPTS}] options ..."
  CATALINA_OPTS="${CATALINA_OPTS:-} ${JVM_LOG_GC_OPTS} -Xloggc:${LOG_DIR}/gc.log"
  # log rotation to backup previous log file (we don't use GC Log file rotation options because they are not suitable)
  # create the directory for older GC log file
  [ ! -d ${LOG_DIR}/gc/ ] && mkdir ${LOG_DIR}/gc/
  if [ -f ${LOG_DIR}/gc.log ]; then
    JVM_LOG_GC_ARCHIVE="${LOG_DIR}/gc/gc_$(date -u +%F_%H%M%S%z).log"
    mv ${LOG_DIR}/gc.log ${JVM_LOG_GC_ARCHIVE}
    echo "previous JVM GC log file archived to ${JVM_LOG_GC_ARCHIVE}."
  fi
  echo "JVM GC logs configured and available at ${LOG_DIR}/platform-gc.log"
fi

# -----------------------------------------------------------------------------
# JVM configuration
# -----------------------------------------------------------------------------
export CATALINA_OPTS="${CATALINA_OPTS:-} -Xmx${JVM_SIZE_MAX} -Xms${JVM_SIZE_MIN}  -XX:MaxMetaspaceSize=${JVM_METASPACE_SIZE_MAX}"

echo "INFO Configuring cmis server..."
cp -v /repository-template.properties ${INSTALL_DIR}/webapps/cmis/WEB-INF/classes/repository.properties
replace_in_file ${INSTALL_DIR}/webapps/cmis/WEB-INF/classes/repository.properties "@CMIS_USERS_PASSWORD@" "${CMIS_USERS_PASSWORD}"
