ThisPath=$(dirname $0)

RepositoryName="languagetool-server"
LanguageToolVersion="6.7"
LanguageToolBuild="20250818"

Tags=()
Tags+=("docker.io/tiol4u/${RepositoryName}:${LanguageToolVersion}")
Tags+=("docker.io/tiol4u/${RepositoryName}:latest")
Tags+=("quay.io/laudivan/${RepositoryName}:${LanguageToolVersion}")
Tags+=("quay.io/laudivan/${RepositoryName}:latest")

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
for Tag in ${Tags[@]}
do
    podman tag ${RepositoryName} $tag
done && \
podman image rm --force ${RepositoryName} && \
\
for Tag in ${Tags[@]}
do
    podman push \
        --compress \
        --compression-level=9 \
        --remove-signatures \
        $Tag

    [[ $? == 0 ]] && podman image rm --force $Tag
done
