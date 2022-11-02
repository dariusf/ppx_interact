
# Optional features

Integration with down and bat may be disabled using the `NO_DOWN` and `NO_BAT` environment variables respectively.

Set `VERBOSE` for extra logging.

# UTop

An early version used a patched utop as a runtime dependency, but that caused some problems:

- [Transitive dependencies can't (yet) be vendored easily without manually mangling names](https://github.com/ocaml/dune/issues/3335)
- utop's completion system doesn't pick up some bindings, for unknown reasons