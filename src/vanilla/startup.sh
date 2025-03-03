#!/bin/ash

EXTRA_PARAM=""

if [ -f /data/eula.txt && $EULA == true ]; then
    echo "eula=${EULA}" > /data/eula.txt
    chmod 444 /data/eula.txt
fi

if [ $BONUS_CHEST == true ]; then
    EXTRA_PARAM+=" --bonusChest"
fi

if [ $SAFE_MODE == true ]; then
    EXTRA_PARAM+=" --safeMode"
fi

cd /data && \
java -Xms${JAVA_MEMORY_START} \
     -Xmx${JAVA_MEMORY} \
     -jar "/app/server.jar" \
        --port 25565 \
        --serverId "${SERVER_ID}" \
        ${EXTRA_PARAM} \
        --nogui