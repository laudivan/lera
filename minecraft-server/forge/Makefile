Image=trpixu.forge.server
QuayRepository=quay.io/tiol4u
DockerRepository=docker.io/tiol4u
InstallationVersion=${MinecraftVersion}-${ForgeVersion}

all: build deploy clean

build:
	podman image build \
		--build-arg="MinecraftVersion=${MinecraftVersion}" \
		--build-arg="ForgeVersion=${ForgeVersion}" \
		--no-cache \
		--force-rm \
		--format=docker \
		--squash \
		--tag=${Image}:${InstallationVersion} \
		--file=Dockerfile_${InstallationVersion} .

test: build
	podman run -it --rm \
	--publish=25565:25565 \
	--env="Eula=true" \
	--env="JavaMaximumHeap=1024M" \
	${Image}:${InstallationVersion}

test-shell:
	podman run -it --rm \
	--entrypoint="/usr/bin/bash" \
	--publish=25565:25565 \
	--env="Eula=true" \
	--env="JavaMaximumHeap=1024M" \
	${Image}:${InstallationVersion}

tag: tag-to-quay tag-to-docker

tag-to-quay:
	podman image tag \
		${Image}:${InstallationVersion} ${QuayRepository}/${Image}:${InstallationVersion}
	
	[[ ${AddLatestTag}==true ]] && podman image tag \
	${QuayRepository}/${Image}:${InstallationVersion} ${QuayRepository}/${Image}:latest

tag-to-docker:
	podman image tag \
		${Image}:${InstallationVersion} ${DockerRepository}/${Image}:${InstallationVersion}

	[[ ${AddLatestTag}==true ]] && podman image tag \
	${DockerRepository}/${Image}:${InstallationVersion} ${DockerRepository}/${Image}:latest

deploy: deploy-to-quay deploy-to-docker

deploy-to-quay:
	podman login --username laudivan --secret login-quay.io quay.io

	podman push \
		--compression-format=gzip \
		--compression-level=9 \
		--format=v2s2 \
		--remove-signatures \
		${QuayRepository}/${Image}:${InstallationVersion}

	[[ ${AddLatestTag}==true ]] && podman push \	
		--compression-format=gzip \
		--compression-level=9 \
		--format=v2s2 \
		--remove-signatures \
		${QuayRepository}/${Image}:latest

deploy-to-docker:
	podman login --username tiol4u --secret login-docker.io docker.io

	podman push \
		--compression-format=gzip \
		--compression-level=9 \
		--format=v2s2 \
		--remove-signatures \
		${DockerRepository}/${Image}:${InstallationVersion}

	[[ ${AddLatestTag}==true ]] && podman push \
		--compression-format=gzip \
		--compression-level=9 \
		--format=v2s2 \
		--remove-signatures \
		${DockerRepository}/${Image}:latest

clean-all: clean
	podman image rm --force \
		${Image}:${InstallationVersion} \
		${QuayRepository}/${Image}:${InstallationVersion} \
		${QuayRepository}/${Image}:latest \
		${DockerRepository}/${Image}:${InstallationVersion} \
		${DockerRepository}/${Image}:latest

clean:
	podman image prune --build-cache --force

help:
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false build"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false test"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false build"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=true deploy"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false build"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false clean"
