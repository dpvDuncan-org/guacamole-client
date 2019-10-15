# see hooks/build and hooks/.config
ARG BASE_IMAGE_PREFIX
FROM ${BASE_IMAGE_PREFIX}alpine

# see hooks/post_checkout
ARG ARCH
COPY .gitignore qemu-${ARCH}-static* /usr/bin/

# see hooks/build and hooks/.config
ARG BASE_IMAGE_PREFIX
FROM ${BASE_IMAGE_PREFIX}alpine

# see hooks/post_checkout
ARG ARCH
COPY qemu-${ARCH}-static /usr/bin

RUN apk update && apk upgrade

FROM alpine

ARG GUACAMOLE_Version
ENV GUACAMOLE_Version=${GUACAMOLE_Version} \
    TOMCAT_MAJOR=8 \
    TOMCAT_Version=8.5.47 \
    JAVA_HOME="/usr/lib/jvm/java-1.8-openjdk" \
    LANG=C.UTF-8 \
    CATALINA_HOME="/usr/local/tomcat" \
    nativeBuildDir="/tmp/nativeBuild" \
    MySQL-Connector-Version="8.0.17" \
    PostGresql-Connector-Version="42.2.8"

ENV TOMCAT_NATIVE_LIBDIR="${CATALINA_HOME}/native-jni-lib" \
    PATH="${CATALINA_HOME}/bin:$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin"

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${TOMCAT_NATIVE_LIBDIR}"

RUN apk add openjdk8-jre-base ca-certificates tar libressl tomcat-native && \
    apk add --virtual .native-build-deps apr-dev gcc libc-dev make openjdk8 libressl-dev tomcat-native-dev curl && \
    cd /tmp && \
    mkdir -p "${CATALINA_HOME}" && \
    mkdir -p /opt/guacamole/mysql /opt/guacamole/postgresql /opt/guacamole/ldap /opt/guacamole/bin && \
    curl -L "http://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_Version}/bin/apache-tomcat-${TOMCAT_Version}.tar.gz" \
        -o - | \
        tar xz -C "${CATALINA_HOME}" --strip-components=1 && \
    curl -L "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-auth-ldap-${GUACAMOLE_Version}.tar.gz" \
        -o - | \
        tar xz -C "/opt/guacamole/ldap" --strip-components=1 \
                                            guacamole-auth-ldap-${GUACAMOLE_Version}/guacamole-auth-ldap-${GUACAMOLE_Version}.jar \
                                            guacamole-auth-ldap-${GUACAMOLE_Version}/schema && \
    curl -L "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-auth-jdbc-${GUACAMOLE_Version}.tar.gz" \
        -o - | \
        tar xz -C "/opt/guacamole/" --strip-components=1 \
                                            guacamole-auth-jdbc-${GUACAMOLE_Version}/mysql \
                                            guacamole-auth-jdbc-${GUACAMOLE_Version}/postgresql && \
    curl -L "https://cdn.mysql.com/Downloads/Connector-J/mysql-connector-java-${MySQL-Connector-Version}.tar.gz" -o - | \
        tar xz -C "/opt/guacamole/mysql" --strip-components=1 \
                                            mysql-connector-java-${MySQL-Connector-Version}/mysql-connector-java-${MySQL-Connector-Version}.jar && \
    curl -L "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-${GUACAMOLE_Version}.war" \
        -o "/opt/guacamole/guacamole.war" && \
    curl -L "https://jdbc.postgresql.org/download/postgresql-${PostGresql-Connector-Version}.jar" \
        -o "/opt/guacamole/postgresql/postgresql-${PostGresql-Connector-Version}.jar" && \
    curl -L "https://raw.githubusercontent.com/apache/incubator-guacamole-client/${GUACAMOLE_Version}/guacamole-docker/bin/start.sh" \
        -o "/opt/guacamole/bin/start.sh" && \
    curl -L "https://raw.githubusercontent.com/apache/incubator-guacamole-client/${GUACAMOLE_Version}/guacamole-docker/bin/initdb.sh" \
        -o "/opt/guacamole/bin/initdb.sh" && \
    set -x && \
    cd "${CATALINA_HOME}" && \
    rm -f bin/*.bat && \
    set -e && \
    nativeLines="$(catalina.sh configtest 2>&1 | grep 'Apache Tomcat Native' | sort -u)" && \
    if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2 ; \
    then \
    echo >&2 "$nativeLines" ; \
    exit 1 ; \
    fi && \
    rm -rf $CATALINA_HOME/webapps/* /tmp/* /var/cache/apk/* && \
    ln -s /opt/guacamole/guacamole.war $CATALINA_HOME/webapps/guacamole.war && \
    chmod +x /opt/guacamole/bin/*.sh

# ports and volumes
EXPOSE 8080

CMD ["/opt/guacamole/bin/start.sh"]