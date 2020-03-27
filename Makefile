export USER_ID := $(shell id -u)
export USER_NAME := $(shell whoami)
export GROUP_ID := $(shell id -g)
export GROUP_NAME := $(shell (groups | cut -f1 -d' '))

build:
	docker image build \
		-t cloud-tooling:dont.push.this.image \
		--build-arg USER_ID=$$USER_ID \
		--build-arg USER_NAME=$$USER_NAME \
		--build-arg GROUP_ID=$$GROUP_ID \
		--build-arg GROUP_NAME=$$GROUP_NAME \
		.
	echo "Build finished, never push this image"

run: build
	docker container run --rm -ti \
		--name cloud-tooling-$$$$ \
 		-v $$HOME/.ssh:/home/$$USER_NAME/.ssh:ro \
 		-v $$HOME/.aws:/home/$$USER_NAME/.aws:ro \
 		-v $$PWD/plans:/home/$$USER_NAME/plans \
 		-v $$PWD/bin:/home/$$USER_NAME/bin \
		cloud-tooling:dont.push.this.image

clean:
	docker image rm cloud-tooling:dont.push.this.image
