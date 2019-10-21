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

ARG GUACAMOLE_Version

ENV GUACAMOLE_Version=${GUACAMOLE_Version} \
    TOMCAT_MAJOR=8 \
    TOMCAT_MINOR=5 \
    JAVA_HOME="/usr/lib/jvm/java-1.8-openjdk" \
    LANG=C.UTF-8 \
    CATALINA_HOME="/usr/local/tomcat" \
    nativeBuildDir="/tmp/nativeBuild" \
    MySQL_Connector_Version="8.0.17" \
    PostGresql_Connector_Version="42.2.8"

ENV TOMCAT_NATIVE_LIBDIR="${CATALINA_HOME}/native-jni-lib" \
    PATH="${CATALINA_HOME}/bin:$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin"

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${TOMCAT_NATIVE_LIBDIR}"

RUN apk --no-cache -U -q upgrade && \
    apk add --no-cache -U -q openjdk8-jre-base ca-certificates && \
    apk add --no-cache --virtual .native-build-deps apr-dev gcc libc-dev make openjdk8 curl jq tar && \
    cd /tmp && \
    mkdir -p "${CATALINA_HOME}" && \
    mkdir -p /opt/guacamole/mysql /opt/guacamole/postgresql /opt/guacamole/ldap /opt/guacamole/bin && \
    export TOMCAT_PATCH=$(curl -s https://www-us.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/ | grep -o v${TOMCAT_MAJOR}.${TOMCAT_MINOR}.*\/ | cut -f 3 -d . | cut -f 1 -d /) && \
    export TOMCAT_Version=${TOMCAT_MAJOR}.${TOMCAT_MINOR}.${TOMCAT_PATCH} && \
    echo "Downloading http://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_Version}/bin/apache-tomcat-${TOMCAT_Version}.tar.gz" && \
    curl -s -L "http://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_Version}/bin/apache-tomcat-${TOMCAT_Version}.tar.gz" \
        -o - | tar xz -C "${CATALINA_HOME}" --strip-components=1 && \
    echo "Downloading http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-auth-ldap-${GUACAMOLE_Version}.tar.gz" && \
    curl -s -L "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-auth-ldap-${GUACAMOLE_Version}.tar.gz" \
        -o - | tar xz -C "/opt/guacamole/ldap" --strip-components=1 \
                                            guacamole-auth-ldap-${GUACAMOLE_Version}/guacamole-auth-ldap-${GUACAMOLE_Version}.jar \
                                            guacamole-auth-ldap-${GUACAMOLE_Version}/schema && \
    echo "Downloading http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-auth-jdbc-${GUACAMOLE_Version}.tar.gzz" && \
    curl -s -L "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-auth-jdbc-${GUACAMOLE_Version}.tar.gz" \
        -o - | tar xz -C "/opt/guacamole/" --strip-components=1 \
                                            guacamole-auth-jdbc-${GUACAMOLE_Version}/mysql \
                                            guacamole-auth-jdbc-${GUACAMOLE_Version}/postgresql && \
    echo "Downloading https://cdn.mysql.com/Downloads/Connector-J/mysql-connector-java-${MySQL_Connector_Version}.tar.gz" && \
    curl -s -L "https://cdn.mysql.com/Downloads/Connector-J/mysql-connector-java-${MySQL_Connector_Version}.tar.gz" \
        -o - | tar xz -C "/opt/guacamole/mysql" --strip-components=1 \
                                            mysql-connector-java-${MySQL_Connector_Version}/mysql-connector-java-${MySQL_Connector_Version}.jar && \
    echo "Downloading http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-${GUACAMOLE_Version}.war" && \
    curl -s -L "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACAMOLE_Version}/binary/guacamole-${GUACAMOLE_Version}.war" \
        -o "/opt/guacamole/guacamole.war" && \
    echo "Downloading https://jdbc.postgresql.org/download/postgresql-${PostGresql_Connector_Version}.jar" && \
    curl -s -L "https://jdbc.postgresql.org/download/postgresql-${PostGresql_Connector_Version}.jar" \
        -o "/opt/guacamole/postgresql/postgresql-${PostGresql_Connector_Version}.jar" && \
    echo "Downloading https://raw.githubusercontent.com/apache/incubator-guacamole-client/${GUACAMOLE_Version}/guacamole-docker/bin/start.sh" && \
    curl -s -L "https://raw.githubusercontent.com/apache/incubator-guacamole-client/${GUACAMOLE_Version}/guacamole-docker/bin/start.sh" \
        -o "/opt/guacamole/bin/start.sh" && \
    echo "Downloading https://raw.githubusercontent.com/apache/incubator-guacamole-client/${GUACAMOLE_Version}/guacamole-docker/bin/initdb.sh" && \
    curl -s -L "https://raw.githubusercontent.com/apache/incubator-guacamole-client/${GUACAMOLE_Version}/guacamole-docker/bin/initdb.sh" \
        -o "/opt/guacamole/bin/initdb.sh" && \
    set -x && \
    cd "${CATALINA_HOME}" && \
    mkdir ${nativeBuildDir} && \
    tar -xzf bin/tomcat-native.tar.gz -C "${nativeBuildDir}" --strip-components=1 && \
    cd "${nativeBuildDir}/native" && \
    ./configure --libdir="/usr/lib" --with-apr="$(which apr-1-config)" --with-java-home="${JAVA_HOME}" --with-ssl=no && \
    make && \
    make install && \
    echo "----------------------------------------------------------" && \
    catalina.sh configtest && \
    rm -rf "${nativeBuildDir}" bin/tomcat-native.tar.gz && \
    apk add --virtual .tomcat-native-rundeps $(scanelf --needed --nobanner --recursive "${TOMCAT_NATIVE_LIBDIR}" | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' | sort -u | xargs -r apk info --installed | sort -u ) && \
    apk del .native-build-deps && \
    echo "----------------------------------------------------------" && \
    catalina.sh configtest && \
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