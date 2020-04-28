.PHONY: all clean static static_docker push tag
RANDOM := $(shell bash -c 'echo $$RANDOM')
CID := "bmtune_static_$(RANDOM)"

all:
	dune build

static:
	@echo NOTE: This target requires a compiler switch with musl-static, see also the static_docker target
	@echo
	dune build src/bmtune_static.exe

static_docker:
	@echo Building _build/bmtune_static.exe in docker
	@echo
	mkdir -p _build
	tar cv src/* Dockerfile Makefile *.opam dune-project | docker build -t bmtune:latest -f Dockerfile -
	docker create --name $(CID) bmtune:latest
	docker cp $(CID):/bmtune _build/bmtune_static
	docker rm $(CID)
	@echo Static executable copied to _build/bmtune_static

tag: static_docker
	docker tag bmtune:latest ssungam/bmtune:latest

push: tag
	docker push ssungam/bmtune:latest

clean:
	dune clean
