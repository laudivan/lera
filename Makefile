TOOL=podman
IMAGE=lera-minecraft-server
TAG=1.21.4
SERVER_TYPE=vanilla

all: build run

build: build-$(TOOL)

build-podman:
	cd $(SERVER_TYPE) && \
	podman image build \
		--file Dockerfile \
		--no-cache \
		--tag $(IMAGE):$(TAG)	

build-docker:
	cd $(SERVER_TYPE) && \
	docker image build \
		--tag $(IMAGE):$(TAG) \
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
		$(IMAGE):$(TAG)

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
		$(IMAGE):$(TAG)

push-docker: build-docker
	docker login
	docker image tag $(IMAGE):$(TAG) laudivanfreire/$(IMAGE):$(TAG)
	docker push laudivanfreire/$(IMAGE):$(TAG)