
# ppx_interact

Many interactive debuggers (pdb, pry, jdb, node inspect, ...) allow arbitrary code to be evaluated when stopped at breakpoints, which is very useful for debugging.
ocamldebug has limited support for this, [only allowing field and variable values to be read](https://ocaml.org/manual/debugger.html#s%3Adebugger-examining-values).
This project attempts to fill this gap.

# Usage

A few prerequisites: you have a Dune project and are building an executable, not a library (expect tests are a WIP).

Use the extension node `[%interact]` to set a breakpoint, like the `debugger` statement in JS.

```ocaml
let succ x = x + 1

let () =
  let xs = [1; 2; 3] in
  let f a =
    [%interact]
  in
  print_endline "hello!";
  f 2;
  print_endline "goodbye!"
```

A REPL will start when it is hit, allowing arbitrary expressions to be evaluated using variables in scope.

```
$ dune exec example/example.bc
hello!
At line 6 in module Dune__exe__Example.
> succ;;
- : int -> int = <fun>
> List.length xs + succ a;;
- : int = 6
> ^D
goodbye!
```

External libraries work as well.

```
> CCList.map CCInt.succ xs;;
- : CCInt.t CCList.t = [2; 3; 4]
```

# Setup

Build a bytecode executable using the following setup:

```diff
  (executable
-  (name example))
+  (name example)
+  (libraries ppx_interact_runtime)
+  (modes byte)
+  (link_flags -linkall)
+  (preprocess
+   (pps ppx_interact)))
```

- The preprocessor and runtime library are standard
- A bytecode executable must be built
- `-linkall` is typical for [building custom toplevels](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-custom-toplevel) and allows the use of external libraries

See the [example project](example) for the full setup.

# Experiences

I've tried this out on a small project (500 LoC) and it works without any noticeable overhead.

# Design

The idea was [originated](https://sympa.inria.fr/sympa/arc/caml-list/2017-05/msg00124.html) [by](https://github.com/ocaml-community/utop/issues/158) [utop](https://github.com/ocaml-community/utop/tree/master/examples/interact):

> utop interact: this is an experimental feature that has existed for a while. However it is a bit painful to setup so it is currently undocumented. However, properly packaged and maybe with the help of a compiler plugin this could be a killer feature.
>
> What it allows you to do is call `UTop_main.interact ()` somewhere in your program. When the execution reaches this point, you get a toplevel in the context of the call to `UTop_main.interact`, allowing you to inspect the environment to understand what is happening

An early version of this used a tweaked utop as a runtime dependency, but that caused some problems:

- [Transitive dependencies can't (yet) be vendored easily without manually mangling names](https://github.com/ocaml/dune/issues/3335)
- utop's completion system doesn't pick up some bindings, for unknown reasons

As such, the current version uses only the [essential code](https://github.com/ocaml-community/utop/blob/master/src/lib/uTop_main.ml) from utop interact, and uses [linenoise](https://github.com/ocaml-community/ocaml-linenoise/) to provide a usable REPL with completions (there's also some unknown issue with combining [`Toploop.loop`](https://github.com/ocaml/ocaml/blob/trunk/toplevel/toploop.ml) and utop interact).
