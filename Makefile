SHELL:=/bin/bash

init:
	docker swarm init || true

_common_folders:
	mkdir -p graphite
	mkdir -p data
.PHONY: _common_folders

_create_env:
	if [ ! -f .env ]; then \
		cp .env.example .env; \
	fi

setup: init _create_env _common_folders

dummy_file:
	mkdir -p data
	echo "Hello World!" > data/input.txt

run:
	zig build run -Doptimize=ReleaseFast

test:
	zig build test --summary all

fmt:
	zig fmt *.zig
	zig fmt **/*.zig

build:
	docker build -t aes_zig -f docker/Dockerfile .

remove:
	if docker stack ls | grep -q aes_zig; then \
        docker stack rm aes_zig; \
	fi
	
deploy:	remove build
	until \
	docker stack deploy \
	-c docker/docker-compose.yaml \
	aes_zig; \
	do sleep 1; \
	done

logs:
	docker service logs aes_zig_app -f