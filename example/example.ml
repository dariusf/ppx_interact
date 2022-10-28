let z = Lib.t

let () =
  let xs = [1; 2; 3] in
  let y = ref 1 in
  let f (_a : int) = [%interact: int] in
  print_endline "hello!";
  let x = f 2 in
  Format.printf "x is: %d@." x;
  Format.printf "y is now: %d@." !y;
  print_endline "goodbye!"
