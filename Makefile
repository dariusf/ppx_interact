
.PHONY: all
all:
	OCAMLRUNPARAM=b dune test --display=short

.PHONY: example
example:
	OCAMLRUNPARAM=b dune exec examples/example.bc
