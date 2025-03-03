#!/bin/bash

EXTRA_PARAM=""

if [ 
    ! -f $DATA_DIR/eula.txt && 
    $EULA == true 
]; then
    echo "eula=${EULA}" > /data/eula.txt
    chmod 444 /data/eula.txt 
fi

if [ $BONUS_CHEST == true ]; then
    EXTRA_PARAM+=" --bonusChest"
fi

if [ $SAFE_MODE == true ]; then
    EXTRA_PARAM+=" --safeMode"
fi

$JAVA_HOME/bin/java -Xms${JAVA_MEMORY_START} -Xmx${JAVA_MEMORY} -jar "${APP_DIR}/server.jar" --port ${SERVER_PORT} --serverId "${SERVER_ID}" ${EXTRA_PARAM} --nogui