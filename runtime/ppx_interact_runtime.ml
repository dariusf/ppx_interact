let view_file ?(use_bat = false) ?(context = (4, 2)) line file =
  match use_bat with
  | false ->
    let ic = open_in file in
    let rec loop skip left =
      if left <= 0 then []
      else
        try
          let line = input_line ic in
          if skip > 0 then loop (skip - 1) left
          else
            let line = if skip = 0 then line else line in
            line :: loop 0 (left - 1)
        with End_of_file -> []
    in
    let before, after = context in
    let lines = loop (line - before - 1) (before + after + 1) in
    let divider = String.init 60 (fun _ -> '_') in
    print_endline divider;
    List.iter print_endline lines;
    print_endline divider;
    print_endline "";
    close_in ic
  | true ->
    Unix.(
      create_process "bat"
        [|
          "--paging=never";
          "--line-range";
          Format.asprintf "%d:%d" (line - fst context) (line + snd context);
          "--highlight-line";
          string_of_int line;
          file;
          "--style";
          "header,numbers,grid";
        |]
        stdin stdout stderr)
    |> ignore

let eval text =
  let lexbuf = Lexing.from_string text in
  let phrase = !Toploop.parse_toplevel_phrase lexbuf in
  ignore (Toploop.execute_phrase false Format.std_formatter phrase)

let get_required_label name args =
  match List.find (fun (lab, _) -> lab = Asttypes.Labelled name) args with
  | _, x -> x
  | exception Not_found -> None

exception Found of Env.t
exception Term of int

type value = V : string * _ -> value

let walk dir ~init ~f =
  let rec loop dir acc =
    let acc = f dir acc in
    ArrayLabels.fold_left (Sys.readdir dir) ~init:acc ~f:(fun acc fn ->
        let fn = Filename.concat dir fn in
        match Unix.lstat fn with
        | { st_kind = S_DIR; _ } -> loop fn acc
        | _ -> acc)
  in
  match Unix.lstat dir with
  | exception Unix.Unix_error (ENOENT, _, _) -> init
  | _ -> loop dir init

let interact ?(use_linenoise = true) ?(search_path = []) ?(build_dir = "_build")
    ~unit ~loc:(fname, lnum, cnum, _) ?(init = []) ~values () =
  Toploop.initialize_toplevel_env ();
  let search_path =
    walk build_dir ~init:search_path ~f:(fun dir acc -> dir :: acc)
  in
  let cmt_fname =
    try Misc.find_in_path_uncap search_path (unit ^ ".cmt")
    with Not_found ->
      Printf.ksprintf failwith "%s.cmt not found in search path!" unit
  in
  (* print_endline cmt_fname; *)
  let cmt_infos = Cmt_format.read_cmt cmt_fname in
  let expr next (e : Typedtree.expression) =
    match e.exp_desc with
    | Texp_apply (_, args) ->
      begin
        try
          match
            (get_required_label "loc" args, get_required_label "values" args)
          with
          | Some l, Some v ->
            let pos = l.exp_loc.loc_start in
            if
              pos.pos_fname = fname && pos.pos_lnum = lnum
              && pos.pos_cnum - pos.pos_bol = cnum
            then raise (Found v.exp_env)
          | _ -> next e
        with Not_found -> next e
      end
    | _ -> next e
  in
  let next iterator e = Tast_iterator.default_iterator.expr iterator e in
  let expr iterator = expr (next iterator) in
  let iter = { Tast_iterator.default_iterator with expr } in
  let search = iter.structure iter in
  try
    begin
      match cmt_infos.cmt_annots with
      | Implementation st -> search st
      | _ -> ()
    end;
    failwith "Couldn't find location in cmt file"
  with Found env ->
    (try
       List.iter Topdirs.dir_directory (search_path @ cmt_infos.cmt_loadpath);
       let env = Envaux.env_of_only_summary env in
       List.iter
         (fun (V (name, v)) -> Toploop.setvalue name (Obj.repr v))
         values;
       Toploop.toplevel_env := env;
       (* let idents = Env.diff Env.empty env in *)
       (* List.iter print_endline (List.map Ident.name idents); *)
       let eval text =
         let lexbuf = Lexing.from_string text in
         let phrase = !Toploop.parse_toplevel_phrase lexbuf in
         ignore (Toploop.execute_phrase true Format.std_formatter phrase)
       in
       let names = List.map (fun (V (name, _)) -> name) values in

       List.iter
         (fun line ->
           try eval line
           with exn ->
             Format.printf "initialization failed: %s@." line;
             Location.report_exception Format.err_formatter exn)
         init;

       (* eval "b;;"; *)
       (* eval "let c = b + 1;;"; *)
       (* let v : int = Obj.obj (Toploop.getvalue "c") in *)
       (* Format.printf "v = %d@." v; *)
       match use_linenoise with
       | false ->
         while true do
           let s = read_line () in
           eval s
         done
       | true ->
         let rec user_input prompt f =
           match LNoise.linenoise prompt with
           | None -> ()
           | Some v ->
             f v;
             user_input prompt f
         in
         (* this goes from front-to-back, which is the right order, so more recent bindings are suggested first *)
         LNoise.set_hints_callback (fun inp ->
             match inp with
             | "" -> None
             | _ ->
               Option.bind
                 (List.find_opt (String.starts_with ~prefix:inp) names)
                 (fun sugg ->
                   let sl = String.length sugg in
                   let il = String.length inp in
                   if il < sl then
                     let s = String.sub sugg il (sl - il) in
                     Some (s, LNoise.White, false)
                   else None));
         LNoise.set_completion_callback (fun so_far ln_completions ->
             List.filter (String.starts_with ~prefix:so_far) names
             |> List.iter (LNoise.add_completion ln_completions));
         user_input "> " (fun s ->
             let s = String.trim s in
             let doesn't_end_with_semicolons s =
               let l = String.length s in
               l < 2 || String.sub s (l - 2) 2 <> ";;"
             in
             let s = if doesn't_end_with_semicolons s then s ^ ";;" else s in
             LNoise.history_add s |> ignore;
             (* LNoise.history_save ~filename:"history.txt" |> ignore; *)
             try eval s
             with exn -> Location.report_exception Format.err_formatter exn)
     with exn ->
       Location.report_exception Format.err_formatter exn;
       exit 2)