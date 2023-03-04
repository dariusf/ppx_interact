
.PHONY: all
all:
	OCAMLRUNPARAM=b dune test --display=short

.PHONY: example
example:
	OCAMLRUNPARAM=b dune exec examples/example.bc

.PHONY: doc
doc:
	dune build @doc
	open _build/default/_doc/_html/index.html
