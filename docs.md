
# Design

An early version used a tweaked utop as a runtime dependency, but that caused some problems:

- [Transitive dependencies can't (yet) be vendored easily without manually mangling names](https://github.com/ocaml/dune/issues/3335)
- utop's completion system doesn't pick up some bindings, for unknown reasons

As such, the current version uses only the [essential code](https://github.com/ocaml-community/utop/blob/master/src/lib/uTop_main.ml) from utop interact, and uses [linenoise](https://github.com/ocaml-community/ocaml-linenoise/) to provide a usable REPL with completions (there are also issues with combining [`Toploop.loop`](https://github.com/ocaml/ocaml/blob/trunk/toplevel/toploop.ml) and utop interact).