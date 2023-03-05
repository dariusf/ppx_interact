(lang dune 3.7)

(name ppx_interact)
(generate_opam_files true)

(source
 (github dariusf/ppx_interact))

(authors "Darius Foo")

(maintainers "darius.foo.tw@gmail.com")

(package
 (name ppx_interact)
 (synopsis "Opens a REPL in context")
 (description "The pry/pdb experience via a toplevel")
 (depends ocaml dune ppxlib ppx_interact_runtime))

(package
 (name ppx_interact_runtime)
 (synopsis "Opens a REPL in context")
 (description "Runtime library for ppx_interact")
 (depends ocaml dune linenoise))
