
module Misc = struct
  let find_in_path_uncap =
    #if OCAML_VERSION < (5,2,0)
      Misc.find_in_path_uncap
    #else
      Misc.find_in_path_normalized
    #endif
end

let get_load_paths cmt_infos =
  #if OCAML_VERSION < (5,2,0)
    cmt_infos.Cmt_format.cmt_loadpath
  #else
    cmt_infos.Cmt_format.cmt_loadpath.visible @
    cmt_infos.cmt_loadpath.hidden
  #endif

(* https://github.com/ocaml/ocaml/commit/e267d7b2422c101afdc683112bb067ab0ff9e195 *)
let apply_arg_to_option a =
  #if OCAML_VERSION < (5,4,0)
    a
  #else
    match a with
    | Typedtree.Arg e -> Some e
    | Omitted () -> None
  #endif