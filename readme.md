
# ppx_interact

utop has had [a bit of](https://sympa.inria.fr/sympa/arc/caml-list/2017-05/msg00124.html) [interesting functionality](https://github.com/ocaml-community/utop/tree/master/examples/interact) for a long time:

> utop interact: this is an experimental feature that has existed for
> a while. However it is a bit painful to setup so it is currently
> undocumented. However, properly packaged and maybe with the help of
> a compiler plugin this could be a killer feature.
>
> What it allows you to do is call `UTop_main.interact ()` somewhere
> in your program. When the execution reaches this point, you get a
> toplevel in the context of the call to `UTop_main.interact`,
> allowing you to inspect the environment to understand what is
> happening

This ppx is an attempt at making this usable for everyday debugging.

# Setup

```sh
# A patched version of utop which better supports invocation as a library
opam pin utop https://github.com/dariusf/utop.git
opam pin ppx_interact https://github.com/dariusf/ppx_interact.git
```

See the [example](example).
In short, executables must be built in bytecode mode [with `-linkall`](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-custom-toplevel), with utop as a runtime dependency and this as a preprocessor.

You may then [use](example/example.ml) the extension node `[%interact]` as you would the `debugger` statement in JS.

# Experiences

I've tried this out on a
