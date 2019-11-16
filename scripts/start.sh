#! /bin/sh
chown -R $PUID:$PGID /config $CATALINA_HOME /opt/guacamole

GROUPNAME=$(getent group $PGID | cut -d: -f1)
USERNAME=$(getent passwd $PUID | cut -d: -f1)

if [ ! $GROUPNAME ]
then
        addgroup -g $PGID medusa
        GROUPNAME=medusa
fi

if [ ! $USERNAME ]
then
        adduser -G $GROUPNAME -u $PUID -D medusa
        USERNAME=medusa
fi

su - $USERNAME -c '/opt/guacamole/bin/start.sh'
