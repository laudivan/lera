ARG BASE_IMAGE=alpine:3.20
    
FROM $BASE_IMAGE AS build

ARG MINECRAFT_SERVER_URL=https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar

RUN apk add --no-cache openjdk21-jre-headless
    
RUN mkdir -p /data /app

ADD --checksum=sha256:1066970b09e9c671844572291c4a871cc1ac2b85838bf7004fa0e778e10f1358 \
    $MINECRAFT_SERVER_URL /app/server.jar
    
ADD startup.sh /app/startup.sh

####
FROM build AS prod

LABEL org.opencontainers.image.title "LERA's Minecraft Vanilla Server"
LABEL org.opencontainers.image.authors "Laudivan Almeida <laudivan@live.com>"
LABEL org.opencontainers.image.version 0
LABEL org.opencontainers.image.revision 0.1
LABEL org.opencontainers.image.license "MIT"
LABEL org.opencontainers.image.description "Minecraft Server Template for me and my kids"
LABEL org.opencontainers.image.created "2025-03-03T18:21:00Z"
LABEL org.opencontainers.image.source ""

EXPOSE 25565
EXPOSE 25575

ENV \
    EULA=false\
    JAVA_MEMORY_START=1024M\
    JAVA_MEMORY=1024M\
    SERVER_ID="LERA's Minecraft Vanilla Server"\
    BONUS_CHEST=false\
    SAFE_MODE=false

VOLUME [ "/data" ]

ENTRYPOINT [ "/bin/sh", "/app/startup.sh" ]