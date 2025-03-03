TOOL=podman
TAG=lera-minecraft-server
SERVER_TYPE=vanilla

all: build run

build: build-$(TOOL)

build-podman:
	cd $(SERVER_TYPE) && \
	podman image build \
		--file Containerfile \
		--no-cache \
		--tag $(TAG)	

build-docker:
	cd $(SERVER_TYPE) && \
	docker image build \
		--file Dockerfile \
		--no-cache \
		--tag $(TAG)

run: run-$(TOOL)

run-podman:
	podman container run \
		--name lera-minecraft-server-testing \
		--rmi \
		--volume=${MINECRAFT_PATH}:/app/data \
		--publish-all \
		--read-only \
		--replace \
		--env=EULA=true \
		$(TAG)

run-docker:
	docker container run \
		--name lera-minecraft-server-testing \
		--rmi \
		--volume=${MINECRAFT_PATH}:/app/data \
		--publish-all \
		--read-only \
		--replace \
		--env=EULA=true \
		$(TAG)