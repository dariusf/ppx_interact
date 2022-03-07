open Ppxlib
module UTop_main = UTop_main

type string = label

let get_name p =
  match p.ppat_desc with Ppat_var { txt = s; _ } -> [s] | _ -> []

let rec build_list ~loc xs =
  let open Ast_helper in
  match xs with
  | [] -> Exp.construct ~loc { txt = Lident "[]"; loc } None
  | x :: xs1 ->
    Exp.construct ~loc { txt = Lident "::"; loc }
      (Some (Exp.tuple ~loc [x; build_list ~loc xs1]))

let traverse () =
  object
    inherit [string list] Ast_traverse.fold_map as super

    method! value_binding vb env =
      let (v, _) = super#value_binding vb env in
      let name = get_name v.pvb_pat in
      (v, name @ env)

    method! structure_item s env =
      let (s1, env) = super#structure_item s env in
      (* TODO handle recursive bindings *)
      match s.pstr_desc with Pstr_value (_, _) | _ -> (s1, env)

    method! expression e env =
      let open Ast_helper in
      let (e, env) = super#expression e env in
      match e.pexp_desc with
      | Pexp_extension ({ txt = s; _ }, _payload) when String.equal s "interact"
        ->
        let loc = e.pexp_loc in
        let elt e =
          let s = Exp.constant ~loc (Const.string ~loc e) in
          let id = Exp.ident ~loc { txt = Lident e; loc } in
          [%expr V ([%e s], [%e id])]
        in
        ( [%expr
            Format.printf
              "At line %d in module %s, with %d variables in scope.@." __LINE__
              __MODULE__
              [%e Exp.constant ~loc (Const.int (List.length env))];
            Ppx_interact.UTop_main.interact ~unit:__MODULE__ ~loc:__POS__
              ~values:[%e build_list ~loc (List.map elt env)]
              ()],
          env )
      | _ -> (e, env)
  end

let transform_impl str =
  let (s, _) = (traverse ())#structure str [] in
  s

let () = Driver.register_transformation ~impl:transform_impl "ppx_interact"
