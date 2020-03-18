export USER_ID := $(shell id -u)
export USER_NAME := $(shell whoami)
export GROUP_ID := $(shell id -g)
export GROUP_NAME := $(shell (groups | cut -f1 -d' '))
export DOCKER_REPO := clevandowski

test-env:
	test -n "$(DOCKER_REPO)" || (echo "DOCKER_REPO is not defined (DOCKER_REPO: dockerhub username or enterprise name). Aborting" && exit 1)

build: test-env
	docker image build \
		-t $$DOCKER_REPO/terraform:1.0 \
		--build-arg USER_ID=$$USER_ID \
		--build-arg USER_NAME=$$USER_NAME \
		--build-arg GROUP_ID=$$GROUP_ID \
		--build-arg GROUP_NAME=$$GROUP_NAME \
		.

run: test-env build
	test -n "$(DOCKER_REPO)" || (echo "DOCKER_REPO is not defined (ex: username). Aborting" && exit 1)

	docker container run --rm -ti \
		--name terraform-$$$$ \
 		-v $$HOME/.ssh:/home/$$USER_NAME/.ssh:ro \
 		-v $$HOME/.aws:/home/$$USER_NAME/.aws:ro \
 		-v $$PWD/plans:/home/$$USER_NAME/plans \
 		-v $$PWD/bin:/home/$$USER_NAME/bin \
		$$DOCKER_REPO/terraform:1.0

clean:
	docker image rm $$DOCKER_REPO/terraform:1.0
	rm -rf 	plans/rancher2/.terraform \
			plans/rancher2/terraform.tfstate* \
			plans/rancher2/ssh_config* \
			plans/rancher2/terraform.tfstate* \
			plans/rancher2/rancher-cluster.* \
			plans/rancher2/inventory.yml \
			plans/rancher2/kube_config_rancher-cluster.yml \
			plans/rancher2/rancher2.plan \
			plans/rancher2/rancher_admin_password.txt
