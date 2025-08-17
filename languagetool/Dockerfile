FROM fedora:latest AS build
ARG VERSION=6.7
ARG BUILD_DT=20250816

ARG LT_CKSUM=3f3476312283a9151abe08e7e379521b7d29de02571817c9d9122161c08cc73b
ARG LB_CKSUM=7e69ec5451bc261cc7844e49e4792a85d7f09c06789ec800fc4a44aec362764e

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
    mv /build/LanguageTool-${VERSION}-SNAPSHOT/* /app

WORKDIR /build/fastText
RUN dnf --assumeyes group install c-development && \
    make && \
    cp /build/fastText/fasttext /app/fasttext

FROM openjdk:latest
ENV PORT=8081
ENV UID=1000
ENV GID=1000

LABEL name="LanguageTool Server" \
      version="$VERSION" \
      maintainer="Laudivan Almeida <lau@hanuky.space>"

COPY --chown=${UID}:${GID} --from=build /app /app

EXPOSE ${PORT}/tcp
EXPOSE ${PORT}/udp

USER ${UID}:${GID}

WORKDIR /app

ENTRYPOINT [\
    "/usr/bin/java", "-cp", \
    "/app/languagetool-server.jar", \
    "org.languagetool.server.HTTPServer", \
    "--config", "/app/server.properties", \
    "--port", "8081", \
    "--public", \
    "--allow-origin", "\"*\"" ]
