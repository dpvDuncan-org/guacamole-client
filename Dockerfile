ARG BASE_IMAGE_PREFIX

FROM multiarch/qemu-user-static as qemu

FROM ${BASE_IMAGE_PREFIX}alpine

COPY --from=qemu /usr/bin/qemu-*-static /usr/bin/

ENV PUID=0
ENV PGID=0

ARG GUACAMOLE_Version
ENV GUACAMOLE_Version=${GUACAMOLE_Version}

ARG TOMCAT_Version
ENV TOMCAT_Version=${TOMCAT_Version}

ARG MySQL_Connector_Version
ENV MySQL_Connector_Version=${MySQL_Connector_Version}

ARG PostGresql_Connector_Version
ENV PostGresql_Connector_Version=${PostGresql_Connector_Version}

ENV JAVA_HOME="/usr/lib/jvm/java-1.8-openjdk"
ENV LANG="C.UTF-8"
ENV CATALINA_HOME="/usr/local/tomcat"
ENV nativeBuildDir="/tmp/nativeBuild"
ENV TOMCAT_NATIVE_LIBDIR="/usr/lib"

ENV PATH="${CATALINA_HOME}/bin:$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${TOMCAT_NATIVE_LIBDIR}"

COPY scripts/start.sh /
COPY tomcat ${CATALINA_HOME}
COPY nativeBuild ${nativeBuildDir}
COPY guacamole /opt/guacamole

RUN echo "ls ${CATALINA_HOME} : $(ls ${CATALINA_HOME})"
RUN echo "ls /tmp : $(ls /tmp)"
RUN echo "ls /opt : $(ls /opt)"

RUN apk -U -q --no-cache upgrade
RUN apk add --no-cache -U -q openjdk8-jre-base ca-certificates
RUN apk add --no-cache -U -q --virtual .native-build-deps apr-dev gcc libc-dev make openjdk8
WORKDIR ${nativeBuildDir}/native
RUN ./configure --libdir="${TOMCAT_NATIVE_LIBDIR}" --with-apr="$(which apr-1-config)" --with-java-home="${JAVA_HOME}" --with-ssl=no
RUN make
RUN make install
WORKDIR ${CATALINA_HOME}
RUN rm -rf "${nativeBuildDir}" bin/tomcat-native.tar.gz
RUN apk add --virtual .tomcat-native-rundeps $(scanelf --needed --nobanner --recursive "${TOMCAT_NATIVE_LIBDIR}" | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' | sort -u | xargs -r apk info --installed | sort -u )
RUN apk del .native-build-deps
RUN rm -f bin/*.bat
RUN set -e && \
    nativeLines="$(catalina.sh configtest 2>&1 | grep 'Apache Tomcat Native' | sort -u)" && \
    if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2 ; \
    then \
    echo >&2 "$nativeLines" ; \
    exit 1 ; \
    fi
RUN rm -rf $CATALINA_HOME/webapps/* /tmp/* /var/cache/apk/* /usr/bin/qemu-*-static
RUN chmod +x /start.sh

# ports and volumes
EXPOSE 8080

CMD ["/start.sh"]
