.PHONY: all clean static
RANDOM := $(shell bash -c 'echo $$RANDOM')
CID := "bmtune_static_$(RANDOM)"

bmtune: main.ml
	ocamlc main.ml -o bmtune

bmtune_static: main.ml
	ocamlopt -ccopt -static main.ml -o bmtune_static

all: bmtune

bmtune_static_docker:
	tar cv main.ml Dockerfile Makefile | docker build -t bmtune:latest -f Dockerfile -
	docker create --name $(CID) bmtune:latest
	docker cp $(CID):/bmtune bmtune_static
	docker rm $(CID)

clean:
	rm -f main.cmi main.cmo main.cmx main.o bmtune bmtune_static
