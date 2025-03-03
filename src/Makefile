TOOL=podman
TAG=lera-minecraft-server
SERVER_TYPE=vanilla

all: build run

build: build-$(TOOL)

build-podman:
	podman image build --file ./$(SERVER_TYPE)/Containerfile --tag $(TAG)

build-docker:
	docker image build --file ./$(SERVER_TYPE)/Dockerfile --tag $(TAG)

run: run-$(TOOL)

run-podman:
	podman container run --name lera-minecraft-server-testing --rmi --volume ${MINECRAFT_PATH}:/app/data --publish-all --read-only --replace $(TAG)

run-docker:
	podman container run --name lera-minecraft-server-testing --rmi --volume ${MINECRAFT_PATH}:/app/data --publish-all --read-only --replace $(TAG)