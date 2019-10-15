NODE_IMG ?= node:latest
TELEPORT_IMG ?= teleport:latest

docker-build: docker-build-node docker-build-teleport

docker-build-node:
	docker build -t $(NODE_IMG) -f Dockerfile.node .

docker-build-teleport:
	docker build -t $(TELEPORT_IMG) -f Dockerfile.teleport .

start-all: start-teleport start-nodes

start-teleport:
	docker run --name teleport --rm -d -t \
	  -p 3023:3023 \
	  -p 3024:3024 \
	  -p 3025:3025 \
	  -p 3080:3080 \
	  $(TELEPORT_IMG)

start-nodes: start-control-plane-node start-worker-node

start-control-plane-node:
	docker run --name control-plane --rm -d -t --privileged \
	  --hostname control-plane \
	  -v /lib/modules:/lib/modules \
	  -v /etc/resolv.conf:/etc/resolv.conf \
	  --tmpfs /run \
	  $(NODE_IMG)

start-worker-node:
	docker run --name worker --rm -d -t --privileged \
	  --hostname worker \
	  -v /lib/modules:/lib/modules \
	  -v /etc/resolv.conf:/etc/resolv.conf \
	  --tmpfs /run \
	  $(NODE_IMG)

list-nodes:
	docker exec -ti teleport tctl nodes ls

add-user:
	docker exec -ti teleport tctl users add $(USER) root

login:
	tsh --proxy=localhost login --insecure 2>/dev/null || true

clean:
	docker stop teleport || true
	docker stop control-plane || true
	docker stop worker || true
