open Ppxlib
module Ast = Ast_builder.Default

(* module UTop_main = UTop_main *)
(* module LNoise = LNoise *)
(* module Interact = Interact *)

type string = label

let get_name p =
  match p.ppat_desc with Ppat_var { txt = s; _ } -> [s] | _ -> []

let rec build_list ~loc xs =
  (* let open Ast_helper in *)
  match xs with
  | [] ->
    (* Exp.construct ~loc { txt = Lident "[]"; loc } None *)
    [%expr []]
  | x :: xs1 -> [%expr [%e x] :: [%e build_list ~loc xs1]]
(* Exp.construct ~loc { txt = Lident "::"; loc } *)
(* (Some (Exp.tuple ~loc [x; build_list ~loc xs1])) *)

let traverse () =
  object
    inherit [string list] Ast_traverse.fold_map as super

    method! value_binding vb env =
      let (v, _) = super#value_binding vb env in
      let name = get_name v.pvb_pat in
      List.iter (fun n -> Format.printf "added: %s@." n) name;
      (v, name @ env)

    method! structure_item s env =
      let (s1, env) = super#structure_item s env in
      (* TODO mutually recursive bindings *)
      match s.pstr_desc with Pstr_value (_, _) | _ -> (s1, env)

    method! expression e env =
      let open Ast_helper in
      (* TODO try moving this into the branches *)
      (* it does help *)
      (* let (e, env) = super#expression e env in *)
      match e.pexp_desc with
      (* tried to generate a binding. but this didn't work *)
      (* | Pexp_fun
           ( label,
             opt,
             ({ ppat_desc = Ppat_var { txt = v; loc }; _ } as pat),
             body ) ->
         Format.printf "added: %s@." v;
         (* let (e, env) = super#expression e env in *)
         (* (e, v :: env) *)
         (* recurse into body *)
         let (body, env) = super#expression body (v :: env) in
         let bind =
           Ast.pexp_let ~loc Nonrecursive
             [
               Ast.value_binding ~loc
                 ~pat:(Ast.ppat_var ~loc { loc; txt = v })
                 ~expr:(Ast.pexp_ident ~loc { loc; txt = Lident v });
             ]
             body
         in
         (Ast.pexp_fun ~loc label opt pat bind, env) *)
      | Pexp_fun (_, _, { ppat_desc = Ppat_var { txt = v; _ }; _ }, _) ->
        Format.printf "added: %s@." v;
        (* update, then recurse into subexpressions *)
        let (e, env) = super#expression e (v :: env) in
        (e, env)
      | Pexp_extension ({ txt = s; _ }, _payload) when String.equal s "interact"
        ->
        List.iter (fun c -> Format.printf "ctx: %s@." c) env;
        let loc = e.pexp_loc in
        let elt e =
          let s = Exp.constant ~loc (Const.string ~loc e) in
          let id = Exp.ident ~loc { txt = Lident e; loc } in
          [%expr V ([%e s], [%e id])]
        in
        let debug = Ast.estring ~loc (String.concat ", " env) in
        let status_print =
          [%expr
            Format.printf
              "At line %d in module %s, with %d variables in scope.\n\n%s\n\n@."
              __LINE__ __MODULE__
              [%e Exp.constant ~loc (Const.int (List.length env))]
              [%e debug]]
        in
        let utop = false in
        let linenoise = true in
        let toplevel =
          match (utop, linenoise) with
          | (true, _) ->
            [%expr
              Ppx_interact.UTop_main.interact ~unit:__MODULE__ ~loc:__POS__
                ~values:[%e build_list ~loc (List.map elt env)]
                ()]
          | (false, false) -> [%expr Topmain.main () |> ignore]
          | (false, true) ->
            [%expr
              Ppx_interact_runtime.interact ~unit:__MODULE__ ~loc:__POS__
                ~values:[%e build_list ~loc (List.map elt env)]
                ()]
        in
        ( [%expr
            [%e status_print];
            [%e toplevel]],
          env )
      | _ ->
        (* (e, env) *)
        super#expression e env
  end

let transform_impl str =
  let (s, _) = (traverse ())#structure str [] in
  s

let () = Driver.register_transformation ~impl:transform_impl "ppx_interact"
