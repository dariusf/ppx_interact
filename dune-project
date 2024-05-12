(lang dune 3.7)

(name ppx_interact)
(generate_opam_files true)

(source
 (github dariusf/ppx_interact))

(authors "Darius Foo")

(maintainers "darius.foo.tw@gmail.com")
(license MIT)

(package
 (name ppx_interact)
 (synopsis "Opens a REPL in context")
 (description "The pry/pdb experience via a toplevel")
 (depends
  (ocaml (>= 4.14))
  (cppo :build)
  (ppxlib (>= 0.28.0))
  (linenoise (>= 1.4.0))))
