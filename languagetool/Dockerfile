FROM fedora:latest AS build
ARG VERSION=6.7 \
    BUILD_DT=20250817 \
    LT_CKSUM=646a3e589b50db033994983e86f0f091c2234ff55249aa0c7c82497d6edce02e \
    LB_CKSUM=7e69ec5451bc261cc7844e49e4792a85d7f09c06789ec800fc4a44aec362764e \
    JAVA_VER=25

ENV LT_ZIP=LanguageTool-${BUILD_DT}-snapshot.zip

WORKDIR /app

ADD --checksum=sha256:$LB_CKSUM \
    https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin \
    /app/

COPY <<EOF /app/server.properties
fasttextModel=/app/lid.176.bin
fasttextBinary=/app/fasttext
EOF

WORKDIR /build

ADD --checksum=sha256:${LT_CKSUM} \
    https://internal1.languagetool.org/snapshots/${LT_ZIP} \
    /build/

ADD https://github.com/facebookresearch/fastText.git /build/fastText

RUN dnf check-update && \
    dnf --assumeyes install unzip && \
    unzip ${LT_ZIP} && \
    mv /build/LanguageTool-${VERSION}-SNAPSHOT/* /app && \
    dnf --assumeyes install java-$JAVA_VER-openjdk-headless.x86_64 && \
    mv /usr/lib/jvm/java-$JAVA_VER-openjdk /app/openjdk

WORKDIR /build/fastText

RUN dnf --assumeyes group install c-development && \
    make && \
    cp /build/fastText/fasttext /app/fasttext

FROM alpine:latest AS languageTool
ENV PORT=8081 \
    UID=1000 \
    GID=1000

LABEL name="LanguageTool Server" \
      version="$VERSION" \
      build="$BUILD_DT" \
      maintainer="Laudivan Almeida <lau@hanuky.space>"

COPY --chown=${UID}:${GID} --from=build /app /app

EXPOSE ${PORT}/tcp

USER ${UID}:${GID}

WORKDIR /app

ENTRYPOINT [\
    "/app/openjdk/bin/java", "-cp", \
    "/app/languagetool-server.jar", \
    "org.languagetool.server.HTTPServer", \
    "--config", "/app/server.properties", \
    "--port", "8081", \
    "--public", \
    "--allow-origin", "\"*\"" ]
