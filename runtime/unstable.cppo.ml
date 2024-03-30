
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