(* box-drawing characters *)
let box_h = "─"
let box_v = "│"
let box_t = "┬"
let box_bot = "┴"

let view_file ?(use_bat = true) ?(context = (4, 2)) line file =
  let show () =
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
    let line_number_width =
      2 + (log10 (line + after |> float_of_int) |> int_of_float)
    in
    let title_width = line_number_width + 3 in
    let divider joint =
      List.init 60 (fun i -> if i = line_number_width + 1 then joint else box_h)
      |> String.concat ""
    in
    print_endline (divider box_h);
    print_endline (String.init title_width (fun _ -> ' ') ^ file);
    print_endline (divider box_t);
    List.iteri
      (fun i l ->
        Format.printf "%*d %s %s\n" line_number_width (i + line - 2) box_v l)
      lines;
    print_endline (divider box_bot);
    close_in ic
  in
  match use_bat with
  | false -> show ()
  | true ->
    let open Unix in
    (match
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
         stdin stdout stderr
       |> waitpid [] |> snd
     with
    | WEXITED 0 -> ()
    | WEXITED _ | WSIGNALED _ | WSTOPPED _
    | (exception Unix_error (ENOENT, "create_process", "bat")) ->
      show ())

let read () =
  let lexbuf = Lexing.from_function Topcommon.refill_lexbuf in
  let phrase = !Toploop.parse_toplevel_phrase lexbuf in
  ignore (Toploop.execute_phrase true Format.std_formatter phrase)

let eval ~show text =
  let lexbuf = Lexing.from_string text in
  let phrase = !Toploop.parse_toplevel_phrase lexbuf in
  ignore (Toploop.execute_phrase show Format.std_formatter phrase)

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

(** https://github.com/ocaml/ocaml/blob/trunk/toplevel/toploop.ml *)
module Toploop2 = struct
  exception PPerror

  let phrase_buffer = Buffer.create 1024

  let loop () =
    let ppf = Format.std_formatter in
    Clflags.debug := true;
    Location.formatter_for_warnings := ppf;
    (* don't initialize the toplevel environment, as we don't want to clear bindings passed in *)
    let lb = Lexing.from_function Topcommon.refill_lexbuf in
    Location.init lb "//toplevel//";
    Location.input_name := "//toplevel//";
    Location.input_lexbuf := Some lb;
    Location.input_phrase_buffer := Some phrase_buffer;
    Sys.catch_break true;
    (* loading ocamlinit is done elsewhere *)
    try
      while true do
        let snap = Btype.snapshot () in
        try
          Lexing.flush_input lb;
          Buffer.reset phrase_buffer;
          Location.reset ();
          Warnings.reset_fatal ();
          Topcommon.first_line := true;
          let phr =
            try !Toploop.parse_toplevel_phrase lb with Exit -> raise PPerror
          in
          let phr = Toploop.preprocess_phrase ppf phr in
          Env.reset_cache_toplevel ();
          ignore (Toploop.execute_phrase true ppf phr)
        with
        | Sys.Break ->
          Btype.backtrack snap;
          raise End_of_file
        | PPerror -> ()
        | x ->
          Location.report_exception ppf x;
          Btype.backtrack snap
      done
    with End_of_file -> ()
end

let linenoise_prompt completion_words =
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
          (List.find_opt (String.starts_with ~prefix:inp) completion_words)
          (fun sugg ->
            let sl = String.length sugg in
            let il = String.length inp in
            if il < sl then
              let s = String.sub sugg il (sl - il) in
              Some (s, LNoise.White, false)
            else None));
  LNoise.set_completion_callback (fun so_far ln_completions ->
      List.filter (String.starts_with ~prefix:so_far) completion_words
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
      try eval ~show:true s
      with exn -> Location.report_exception Format.err_formatter exn)

(** see https://github.com/ocaml-community/utop/blob/master/src/lib/uTop_main.ml *)
let interact ?(search_path = []) ?(build_dir = "_build") ~unit
    ~loc:(fname, lnum, cnum, _) ?(init = []) ~values () =
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
       let names = List.map (fun (V (name, _)) -> name) values in

       List.iter
         (fun line ->
           try eval ~show:true line
           with exn ->
             Format.printf "initialization failed: %s@." line;
             Location.report_exception Format.err_formatter exn)
         init;

       (* eval "b;;"; *)
       (* eval "let c = b + 1;;"; *)
       (* let v : int = Obj.obj (Toploop.getvalue "c") in *)
       (* Format.printf "v = %d@." v; *)
       let use_linenoise = Sys.getenv_opt "LINENOISE" |> Option.is_some in
       match use_linenoise with
       | false -> Toploop2.loop ()
       | true -> linenoise_prompt names
     with exn ->
       Location.report_exception Format.err_formatter exn;
       exit 2)
