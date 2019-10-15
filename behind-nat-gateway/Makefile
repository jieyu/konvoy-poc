NODE_IMG ?= node:latest
TELEPORT_IMG ?= teleport:latest

docker-build: docker-build-node docker-build-teleport

docker-build-node:
	docker build -t $(NODE_IMG) -f Dockerfile.node .

docker-build-teleport:
	docker build -t $(TELEPORT_IMG) -f Dockerfile.teleport .

start-all:
	terraform init
	terraform apply -auto-approve

list-nodes:
	docker exec -ti teleport tctl nodes ls

add-user:
	docker exec -ti teleport tctl users add $(USER) root

login:
	tsh --proxy=localhost login --insecure 2>/dev/null || true

clean:
	terraform destroy -auto-approve || true
	docker stop teleport || true
	rm -rf runs/ terraform.tfstate* admin.conf .terraform/
