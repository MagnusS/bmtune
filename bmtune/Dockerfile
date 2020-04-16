FROM ocaml/opam2 as build

RUN sudo apt-get install -y musl-tools
RUN opam switch create -y 4.08.1+musl+static+flambda
COPY --chown=opam:opam . /home/opam/app
WORKDIR /home/opam/app
RUN eval $(opam env) && \
	make bmtune_static && \
	strip bmtune_static

FROM scratch

COPY --from=build /home/opam/app/bmtune_static /bmtune

ENTRYPOINT ["/bmtune"]
