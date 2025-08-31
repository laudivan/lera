Image=trpixu.forge.server
QuayRepository=quay.io/tiol4au
DockerRepository=docker.io/tiol4au
InstallationVersion=${MinecraftVersion}-${ForgeVersion}

all: build deploy clean

build:
	podman image build \
		--build-arg="MinecraftVersion=${MinecraftVersion}" \
		--build-arg="ForgeVersion=${ForgeVersion}" \
		--tag=${Image}:${InstallationVersion} \
		--file=Containerfile_${InstallationVersion}	.

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
		${Image}:${InstallationVersion} quay.io/tiol4au/${Image}:${InstallationVersion}
	
	[[ ${AddLatestTag}==true ]] && podman image tag \
	quay.io/tiol4au/${Image}:${InstallationVersion} quay.io/tiol4au/${Image}:latest

tag-to-docker:
	podman image tag \
		${Image}:${InstallationVersion} docker.io/tiol4au/${Image}:${InstallationVersion}

	[[ ${AddLatestTag}==true ]] && podman image tag \
	docker.io/tiol4au/${Image}:${InstallationVersion} docker.io/tiol4au/${Image}:latest

deploy: deploy-to-quay deploy-to-docker

deploy-to-quay:
	podman login --username laudivan --secret login-quay.io quay.io

	podman push quay.io/tiol4au/${Image}:${InstallationVersion}

	[[ ${AddLatestTag}==true ]] && podman push quay.io/tiol4au/${Image}:latest

deploy-to-docker:
	podman login --username tiol4u --secret login-docker.io docker.io

	podman push docker.io/tiol4au/${Image}:${InstallationVersion}

	[[ ${AddLatestTag}==true ]] && podman push docker.io/tiol4au/${Image}:latest

clean-all: clean
	podman image rm --force \
		${Image}:${InstallationVersion} \
		quay.io/tiol4au/${Image}:${InstallationVersion} \
		quay.io/tiol4au/${Image}:latest \
		docker.io/tiol4au/${Image}:${InstallationVersion} \
		docker.io/tiol4au/${Image}:latest

clean:
	podman image prune --build-cache --force

help:
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false build"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false test"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false build"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=true deploy"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false build"
	echo "make MinecraftVersion=1.21.8 ForgeVersion=58.1.0 AddLatestTag=false clean"