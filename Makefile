.PHONY: all clean static
RANDOM := $(shell bash -c 'echo $$RANDOM')
CID := "bmtune_static_$(RANDOM)"

_build/bmtune: src/main.ml
	mkdir -p _build
	ocamlc src/main.ml -o _build/bmtune

_build/bmtune_static: src/main.ml
	mkdir -p _build
	ocamlopt -ccopt -static src/main.ml -o _build/bmtune_static

all: _build/bmtune

bmtune_static_docker:
	mkdir -p _build
	tar cv src/main.ml Dockerfile Makefile | docker build -t bmtune:latest -f Dockerfile -
	docker create --name $(CID) bmtune:latest
	docker cp $(CID):/bmtune _build/bmtune_static
	docker rm $(CID)

clean:
	rm -rf _build
	rm -f src/main.cmi src/main.cmo
