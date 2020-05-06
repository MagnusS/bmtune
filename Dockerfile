FROM ocaml/opam2 as build

RUN sudo apt-get install -y musl-tools
RUN opam switch create -y 4.08.1+musl+static+flambda
RUN eval $(opam env) && \
	opam install -y dune
COPY --chown=opam:opam . /home/opam/app
WORKDIR /home/opam/app
RUN eval $(opam env) && \
	make static && \
	strip _build/default/src/bmtune.exe

FROM scratch

COPY --from=build /home/opam/app/_build/default/src/bmtune.exe /bmtune

ENTRYPOINT ["/bmtune"]
