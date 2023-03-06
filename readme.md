
# ppx_interact

Interactive breakpoints!

Use the extension node `[%interact]` to set a breakpoint, like the `debugger` statement in JavaScript.

```ocaml
let succ x = x + 1

let () =
  let xs = [1; 2; 3] in
  let f (a : int) =
    [%interact]
  in
  print_endline "hello!";
  f 2;
  print_endline "goodbye!"
```

A REPL will start when it is evaluated, allowing arbitrary expressions to be evaluated using variables in scope.

```
$ dune exec examples/simple.bc
hello!
────────────────────────────────────────────────────────────
     examples/simple.ml
───┬────────────────────────────────────────────────────────
 1 │ let succ x = x + 1
 2 │
 3 │ let () =
 4 │   let xs = [1; 2; 3] in
 5 │   let f (a : int) = [%interact] in
 6 │   print_endline "hello!";
 7 │   f 2;
───┴────────────────────────────────────────────────────────
> succ
- : int -> int = <fun>
> List.length xs + succ a
- : int = 6
> ^D
goodbye!
```

External libraries work as well.

```
> CCList.map CCInt.succ xs;;
- : CCInt.t CCList.t = [2; 3; 4]
```

Use a type payload to specify the return type of the extension node. The return value is given by assigning to the write-only ref `_ret`.

```ocaml
let x = [%interact: int] in
Format.printf "x = %d@." x
```

```
> _ret := 3
- : unit = ()
> ^D
x = 3
```

Toplevel directives are available. Standard things like `#use "topfind"` to `#require` and `#show` the module signatures of a package are possible.

It is also possible to `#trace` functions and call them on values in context. This persists across breakpoints, so use `#untrace_all` to disable tracing.

.ocamlinit files are loaded, so if you use one to `#install_printer`s and open modules for `dune utop`, everything should work the same.

[down](https://github.com/dbuenzli/down) works and will be automatically loaded if available. Otherwise, a simpler [linenoise](https://github.com/ocaml-community/ocaml-linenoise/) REPL with support for completions will be used.

If [bat](https://github.com/sharkdp/bat) is installed, it will be invoked to show the context with syntax highlighting.

See the [docs](docs.md) for more details.

# Usage

```sh
opam install ppx_interact
```

Build a bytecode executable using the following setup:

```diff
  (executable
-  (name example))
+  (name example)
+  (modes byte)
+  (link_flags -linkall)
+  (preprocess (pps ppx_interact)))
```

- The executable must be built in bytecode mode (this may be relaxed when the [native toplevel](https://github.com/ocaml/RFCs/pull/15) is mature)
- `-linkall` is typical for [building custom toplevels](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-custom-toplevel) and allows the use of external libraries

See the [example project](example) for the full setup.

Currently this only works with executables, and not expect tests in libraries ([open PR](https://github.com/ocaml/dune/pull/5622)).

The runtime library of this project can also be used standalone to support scripting use cases, e.g. in [ppx_debug](https://github.com/dariusf/ppx_debug).

# Background

Unlike many interactive debuggers (pdb, pry, jdb, node inspect, ...), ocamldebug has limited support for evaluating code when stopped at breakpoints, [only allowing field and variable values to be read](https://v2.ocaml.org/manual/debugger.html#s%3Adebugger-examining-values).

The idea to use a toplevel to support this [originated](https://sympa.inria.fr/sympa/arc/caml-list/2017-05/msg00124.html) [in](https://github.com/ocaml-community/utop/issues/158) [utop](https://github.com/ocaml-community/utop/tree/master/examples/interact):

> utop interact: this is an experimental feature that has existed for a while. However it is a bit painful to setup so it is currently undocumented. However, properly packaged and maybe with the help of a compiler plugin this could be a killer feature.
>
> What it allows you to do is call `UTop_main.interact ()` somewhere in your program. When the execution reaches this point, you get a toplevel in the context of the call to `UTop_main.interact`, allowing you to inspect the environment to understand what is happening

ppx_interact implements this idea.
