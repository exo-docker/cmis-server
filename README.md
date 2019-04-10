# CMIS 1.1 compliant opencmis server <!-- omit in toc -->

- [CMIS 1.1 compliant opencmis server](#cmis-11-compliant-opencmis-server)
  - [Docker](#docker)
  - [How to use it](#how-to-use-it)
    - [CMIS 1.1](#cmis-11)
    - [CMIS 1.0](#cmis-10)
    - [Authentication](#authentication)
  - [Configuration options](#configuration-options)
    - [CMIS](#cmis)
    - [JVM](#jvm)
    - [Frontend proxy](#frontend-proxy)
    - [Tomcat](#tomcat)
    - [JMX](#jmx)

## Docker
```
docker build -t opencmis .
docker run -p 9000:8080 opencmis
```

## How to use it
### CMIS 1.1
WS (SOAP) Binding: http://localhost:9000/cmis/services11/cmis?wsdl
AtomPub Binding: http://localhost:9000/cmis/atom11
Browser Binding: http://localhost:9000/cmis/browser

### CMIS 1.0
WS (SOAP) Binding: http://localhost:9000/cmis/services/cmis?wsdl
AtomPub Binding: http://localhost:9000/cmis/atom

### Authentication
Basic Authentication 

Default users :
  * user1 / cm1sp@ssword
  * user2 / cm1sp@ssword
  * user3 / cm1sp@ssword
  * user4 / cm1sp@ssword
  * user5 / cm1sp@ssword

## Configuration options

All the following options can be defined with standard Docker `-e` parameter

```bash
docker run -e MY_ENV_VARIABLE="value" ... exoplatform/cmis-server
```

or Docker Compose way of defining environment variables

```yaml
version: '2'
services:
...
  exo:
    image: exoplatform/cmis-server
    environment:
...
      JVM_LOG_GC_ENABLED: true
      CMIS_USERS_PASSWORD: mycomplicatedpassword
...
```

### CMIS

5 users (``user1``, ..., ``user5``) are created by default in the cmis container. Their password can be provided with this environment option :

| VARIABLE            | MANDATORY | DEFAULT VALUE  | DESCRIPTION                     |
|---------------------|-----------|----------------|---------------------------------|
| CMIS_USERS_PASSWORD | NO        | `cm1sp@ssword` | specify the cmis users password |

### JVM

This environment variables can be used :

| VARIABLE               | MANDATORY | DEFAULT VALUE | DESCRIPTION                                                                            |
|------------------------|-----------|---------------|----------------------------------------------------------------------------------------|
| JVM_SIZE_MIN           | NO        | `512m`        | specify the jvm minimum allocated memory size (-Xms parameter)                         |
| JVM_SIZE_MAX           | NO        | `512m`        | specify the jvm maximum allocated memory size (-Xmx parameter)                         |
| JVM_METASPACE_SIZE_MAX | NO        | `128m`        | specify the jvm maximum allocated memory to MetaSpace (-XX:MaxMetaspaceSize parameter) |
| JVM_LOG_GC_ENABLED     | NO        | `false`       | activate the JVM GC log file generation (location: $EXO_LOG_DIR/platform-gc.log)       |

### Frontend proxy

The following environment variables must be passed to the container to configure Tomcat proxy settings:

| VARIABLE    | MANDATORY | DEFAULT VALUE | DESCRIPTION                                                                                                                                |
|-------------|-----------|---------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| PROXY_VHOST | NO        | `localhost`   | specify the virtual host name to reach eXo Platform                                                                                        |
| PROXY_PORT  | NO        | -             | which port to use on the proxy server ? (if empty it will automatically defined regarding EXO_PROXY_SSL value : true => 443 / false => 80) |
| PROXY_SSL   | NO        | `true`        | is ssl activated on the proxy server ? (true / false)                                                                                      |

### Tomcat

The following environment variables can be passed to the container to configure Tomcat settings

| VARIABLE           | MANDATORY | DEFAULT VALUE | DESCRIPTION                                                                  |
|--------------------|-----------|---------------|------------------------------------------------------------------------------|
| HTTP_THREAD_MAX    | NO        | `200`         | maximum number of threads in the tomcat http connector                       |
| HTTP_THREAD_MIN    | NO        | `10`          | minimum number of threads ready in the tomcat http connector                 |
| ACCESS_LOG_ENABLED | NO        | `false`       | activate Tomcat access log with combine format and a daily log file rotation |

### JMX

The following environment variables should be passed to the container in order to configure JMX :

| VARIABLE                | MANDATORY | DEFAULT VALUE | DESCRIPTION                                                                                                                               |
|-------------------------|-----------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| JMX_ENABLED             | NO        | `true`        | activate JMX listener                                                                                                                     |
| JMX_RMI_REGISTRY_PORT   | NO        | `10001`       | JMX RMI Registry port                                                                                                                     |
| JMX_RMI_SERVER_PORT     | NO        | `10002`       | JMX RMI Server port                                                                                                                       |
| JMX_RMI_SERVER_HOSTNAME | NO        | `localhost`   | JMX RMI Server hostname                                                                                                                   |
| JMX_USERNAME            | NO        | -             | a username for JMX connection (if no username is provided, the JMX access is unprotected)                                                 |
| JMX_PASSWORD            | NO        | -             | a password for JMX connection (if no password is specified a random one will be generated and stored in /opt/exo/conf/jmxremote.password) |

With the default parameters you can connect to JMX with `service:jmx:rmi://localhost:10002/jndi/rmi://localhost:10001/jmxrmi` without authentication.

