TOOL=podman
TAG=lera-minecraft-server:latest
SERVER_TYPE=vanilla

all: build run

build: build-$(TOOL)

build-podman:
	cd $(SERVER_TYPE) && \
	podman image build \
		--file Dockerfile \
		--no-cache \
		--tag $(TAG)	

build-docker:
	cd $(SERVER_TYPE) && \
	docker image build \
		--no-cache \
		--tag $(TAG) \
		.

run: run-$(TOOL)

run-podman:
	podman container run \
		--name lera-minecraft-server-testing \
		--detach \
		--rmi \
		--volume=lera-minecraft-server-data:/data \
		--publish-all \
		--read-only \
		--replace \
		--env=EULA=true \
		$(TAG)

run-docker:
	docker container run \
		--name lera-minecraft-server-testing \
		--detach \
		--rmi \
		--volume=lera-minecraft-server-data:/data \
		--publish-all \
		--read-only \
		--replace \
		--env=EULA=true \
		$(TAG)