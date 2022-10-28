open Ppxlib
module Ast = Ast_builder.Default

type string = label

let ret_name = "_ret"

let get_name p =
  match p.ppat_desc with Ppat_var { txt = s; _ } -> [s] | _ -> []

let build_list ~loc xs =
  List.fold_right (fun c t -> [%expr [%e c] :: [%e t]]) xs [%expr []]

let build_qmodule xs =
  match xs with
  | [] -> failwith "invalid empty identifier"
  | [x] -> Lident x
  | x :: xs -> List.fold_left (fun t c -> Ldot (t, c)) (Lident x) xs

type env = {
  bindings : (string * string list * Longident.t) list;
  module_context : string list;
}

let empty_env = { module_context = []; bindings = [] }

(* copied from Ast_traverse *)
let var_names_of =
  object
    inherit [string list] Ast_traverse.fold as super

    method! pattern p acc =
      let acc = super#pattern p acc in
      match p.ppat_desc with Ppat_var { txt; _ } -> txt :: acc | _ -> acc
  end

let traverse () =
  object
    inherit [env] Ast_traverse.fold_map as super

    method! value_binding vb env =
      let v, _ = super#value_binding vb env in
      let name = get_name v.pvb_pat in
      ( v,
        {
          env with
          bindings =
            List.map
              (fun n ->
                let ident =
                  match env.module_context with
                  | [] -> Lident n
                  | _ -> build_qmodule (List.rev (n :: env.module_context))
                in
                (n, env.module_context, ident))
              name
            @ env.bindings;
        } )

    method! structure_item s env =
      match s.pstr_desc with
      | Pstr_module { pmb_name = { txt = Some name; _ }; _ } ->
        let s, env1 =
          super#structure_item s
            { env with module_context = name :: env.module_context }
        in
        (* restore the old module context as we exit *)
        (s, { env1 with module_context = env.module_context })
      | Pstr_value (_, _) ->
        (* TODO mutually recursive bindings *)
        super#structure_item s env
      | _ -> super#structure_item s env

    method! expression e env =
      let open Ast_helper in
      match e.pexp_desc with
      | Pexp_fun (_, _, pat, _) ->
        let vs = var_names_of#pattern pat [] in
        (* update env, and only then recurse into subexpressions *)
        let env1 =
          List.fold_right
            (fun c t ->
              {
                t with
                bindings = (c, env.module_context, Lident c) :: t.bindings;
              })
            vs env
        in
        let e, env = super#expression e env1 in
        (e, env)
      | Pexp_extension ({ txt = s; _ }, payload) when String.equal s "interact"
        ->
        let loc = e.pexp_loc in
        let elt (name, original_ctx, ident) =
          let s = Exp.constant ~loc (Const.string ~loc name) in
          let id =
            Exp.ident ~loc
              {
                txt =
                  (* check at the use site if we're still in that module, if so don't qualify *)
                  (if env.module_context != original_ctx then ident
                  else Lident name);
                loc;
              }
          in
          [%expr V ([%e s], [%e id])]
        in
        let dump_variables = false in
        let count_variables = false in
        let debug =
          if dump_variables then
            Ast.estring ~loc
              ("\n\n"
              ^ String.concat ", "
                  (env.bindings |> List.rev |> List.map (fun (a, _, _) -> a))
              ^ "\n\n")
          else [%expr ""]
        in
        let variable_stats =
          if count_variables then
            [%expr
              Format.sprintf ", with %d variables in scope"
                [%e Exp.constant ~loc (Const.int (List.length env.bindings))]]
          else [%expr ""]
        in
        let _status_print =
          [%expr
            Format.printf "At line %d in module %s%s.%s@." __LINE__ __MODULE__
              [%e variable_stats] [%e debug]]
        in
        (* turning this back on requires utop to be added as a runtime dependency *)
        let utop = false in
        let return_type = match payload with PTyp t -> Some t | _ -> None in
        let all_bindings =
          match return_type with
          | None -> env.bindings
          | Some _ -> (ret_name, [], Lident ret_name) :: env.bindings
        in
        let elts = List.map elt all_bindings in
        let toplevel_call =
          match utop with
          | true ->
            [%expr
              Ppx_interact.UTop_main.interact ~unit:__MODULE__ ~loc:__POS__
                ~values:[%e build_list ~loc elts] ()]
          | false ->
            [%expr
              Ppx_interact_runtime.interact ~unit:__MODULE__ ~loc:__POS__
                ~values:[%e build_list ~loc elts] ()]
        in
        let use_bat = true in
        let show_source =
          let file_name = loc.loc_start.pos_fname in
          let line = loc.loc_start.pos_lnum in
          [%expr
            Ppx_interact_runtime.view_file ~use_bat:[%e Ast.ebool ~loc use_bat]
              [%e Ast.eint ~loc line] [%e Ast.estring ~loc file_name]]
        in

        let breakpoint =
          [%expr
            (* [%e status_print]; *)
            [%e show_source];
            [%e toplevel_call]]
        in
        let breakpoint_ret =
          let ret_pat = Ast.ppat_var ~loc { loc; txt = ret_name } in
          let ret_var = Ast.pexp_ident ~loc { loc; txt = Lident ret_name } in
          let ref_type t =
            Ast.ptyp_constr ~loc { loc; txt = Lident "ref" } [t]
          in
          match return_type with
          | Some t ->
            [%expr
              let ([%p ret_pat] : [%t ref_type t]) = ref (Obj.magic ()) in
              [%e breakpoint];
              ![%e ret_var]]
          | None -> breakpoint
        in
        (breakpoint_ret, env)
      | _ -> super#expression e env
  end

let transform_impl ctxt str =
  let _file = Expansion_context.Base.code_path ctxt |> Code_path.file_path in
  let s, _ = (traverse ())#structure str empty_env in
  s

let () = Driver.V2.register_transformation ~impl:transform_impl "ppx_interact"
