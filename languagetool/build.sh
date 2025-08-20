ThisPath=$(dirname $0)

RepositoryName="languagetool-server"
LanguageToolVersion="6.7"
LanguageToolBuild="20250819"

Targets=()
Targets+=("docker.io/tiol4u/${RepositoryName}")
Targets+=("docker.io/tiol4u/${RepositoryName}")
Targets+=("quay.io/tiol4u/${RepositoryName}")
Targets+=("quay.io/tiol4u/${RepositoryName}")

Tags=()
Tags+=($LanguageToolVersion)
Tags+=("latest")

echo "Starting to build"

podman image build \
    --no-cache \
    --build-arg=LanguageToolVersion=${LanguageToolVersion} \
    --build-arg=LanguageToolBuild=${LanguageToolBuild} \
    --build-arg=BuildDate="$(date --utc '+%F %T UTC')" \
    --target=languageTool --file=$ThisPath/Containerfile \
    --rm --layers=false \
    --tag=${RepositoryName} \
    $ThisPath && \
\
echo -e "\n\n--=====  PUBLISHING  =====--\n\n"; \
\
for Target in ${Targets[@]}; do
    for Tag in ${Tags[@]}; do
        echo -e "\t-=: Publishing ${Target}:${Tag} :=- "

        podman tag "localhost/${RepositoryName}" "${Target}:${Tag}"
        podman push --compress --compression-level=9 \
        --remove-signatures "${Target}:${Tag}"
        [[ $? == 0 ]] && podman image rm --force "${Target}:${Tag}"
    done
done && \
\
podman image rm --force "localhost/${RepositoryName}"
