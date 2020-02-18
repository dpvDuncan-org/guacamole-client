#! /bin/sh
chown -R $PUID:$PGID /config $CATALINA_HOME /opt/guacamole

GROUPNAME=$(getent group $PGID | cut -d: -f1)
USERNAME=$(getent passwd $PUID | cut -d: -f1)

if [ ! $GROUPNAME ]
then
        addgroup -g $PGID guacamole
        GROUPNAME=guacamole
fi

if [ ! $USERNAME ]
then
        adduser -G $GROUPNAME -u $PUID -D guacamole
        USERNAME=guacamole
fi

if [ ! ${BASE_URL} ]
then
        ln -s /opt/guacamole/guacamole.war $CATALINA_HOME/webapps/ROOT.war
else
        ln -s /opt/guacamole/guacamole.war $CATALINA_HOME/webapps/${BASE_URL}.war
fi

su -g $GROUPNAME $USERNAME -c '/opt/guacamole/bin/start.sh'
