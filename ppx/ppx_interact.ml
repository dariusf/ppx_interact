open Ppxlib
module Ast = Ast_builder.Default

type string = label

let get_name p =
  match p.ppat_desc with Ppat_var { txt = s; _ } -> [s] | _ -> []

let build_list ~loc xs =
  List.fold_right (fun c t -> [%expr [%e c] :: [%e t]]) xs [%expr []]

let traverse () =
  object
    inherit [string list] Ast_traverse.fold_map as super

    method! value_binding vb env =
      let (v, _) = super#value_binding vb env in
      let name = get_name v.pvb_pat in
      (v, name @ env)

    method! structure_item s env =
      let (s1, env) = super#structure_item s env in
      (* TODO mutually recursive bindings *)
      match s.pstr_desc with Pstr_value (_, _) | _ -> (s1, env)

    method! expression e env =
      let open Ast_helper in
      match e.pexp_desc with
      | Pexp_fun (_, _, { ppat_desc = Ppat_var { txt = v; _ }; _ }, _) ->
        (* update, and only then recurse into subexpressions *)
        let (e, env) = super#expression e (v :: env) in
        (e, env)
      | Pexp_extension ({ txt = s; _ }, _payload) when String.equal s "interact"
        ->
        let loc = e.pexp_loc in
        let elt e =
          let s = Exp.constant ~loc (Const.string ~loc e) in
          let id = Exp.ident ~loc { txt = Lident e; loc } in
          [%expr V ([%e s], [%e id])]
        in
        let dump_variables = false in
        let count_variables = false in
        let debug =
          if dump_variables then
            Ast.estring ~loc
              ("\n\n" ^ String.concat ", " (List.rev env) ^ "\n\n")
          else
            [%expr ""]
        in
        let variable_stats =
          if count_variables then
            [%expr
              Format.sprintf ", with %d variables in scope"
                [%e Exp.constant ~loc (Const.int (List.length env))]]
          else
            [%expr ""]
        in
        let status_print =
          [%expr
            Format.printf "At line %d in module %s%s.%s@." __LINE__ __MODULE__
              [%e variable_stats] [%e debug]]
        in
        (* turning this back on requires utop to be added as a runtime dependency *)
        let utop = false in
        let toplevel =
          match utop with
          | true ->
            [%expr
              Ppx_interact.UTop_main.interact ~unit:__MODULE__ ~loc:__POS__
                ~values:[%e build_list ~loc (List.map elt env)]
                ()]
          | false ->
            [%expr
              Ppx_interact_runtime.interact ~unit:__MODULE__ ~loc:__POS__
                ~values:[%e build_list ~loc (List.map elt env)]
                ()]
        in
        ( [%expr
            [%e status_print];
            [%e toplevel]],
          env )
      | _ -> super#expression e env
  end

let transform_impl str =
  let (s, _) = (traverse ())#structure str [] in
  s

let () = Driver.register_transformation ~impl:transform_impl "ppx_interact"
