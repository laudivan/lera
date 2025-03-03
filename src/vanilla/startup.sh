#!/bin/bash

if [ 
    ! -f $DATA_DIR/eula.txt && 
    $EULA == true 
]; then
    echo "eula=${EULA}" > /data/eula.txt
    chmod 444 /data/eula.txt 
fi

$JAVA_HOME/bin/java -Xms${JAVA_MEMORY_START} -Xmx${JAVA_MEMORY} -jar /server.jar -nogui