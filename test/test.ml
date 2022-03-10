(* module SMap = struct
     include Map.Make (struct
       type t = string

       let compare = compare
     end)

     let pp pp_v fmt map =
       (* Format.fprintf fmt "{@[<2>@,%a@]@,}" *)
       (* ???? *)
       Format.fprintf fmt "{@[<-23>@,%a@]@,}"
         (Format.pp_print_list
            ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@,")
            (fun fmt (k, v) ->
              (* Format.fprintf fmt "%s -> %s" k (sprintf_ "%a" pp_v v))) *)
              Format.fprintf fmt "%s: %a" k pp_v v))
         (bindings map)

     let update_ k f m =
       update k (function None -> failwith "invalid" | Some v -> Some (f v)) m
   end *)

module A = struct
  let one = 1

  module C = struct
    let nested = 1
  end
end

let a () =
  let e = 1 in
  2

let () =
  let _ =
    let d = 3 in
    [%interact]
  in
  let b = 2 in
  let f a = [%interact] in
  [%interact];
  f 2

module B = struct
  let inside = 2
  let () = [%interact]
end
