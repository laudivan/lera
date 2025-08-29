EXTRA_PARAM=""

cd /data

if [ ! -f /data/eula.txt ]; then
    java -jar "/app/server.jar" \
        --serverId "${SERVER_ID}" \
        --initSettings \
        --nogui
fi

if [ $EULA ]; then
    sed -i 's/eula=false/eula=true/g' /data/eula.txt
fi

if [ $BONUS_CHEST = true ]; then
    EXTRA_PARAM+=" --bonusChest"
fi

if [ $SAFE_MODE = true ]; then
    EXTRA_PARAM+=" --safeMode"
fi

java \
    -Xms${JAVA_MEMORY_START} \
    -Xmx${JAVA_MEMORY} \
    -jar "/app/server.jar" \
        --port 25565 \
        --serverId "${SERVER_ID}" \
        ${EXTRA_PARAM} \
        --nogui