let succ x = x + 1

let () =
  let xs = [1; 2; 3] in
  let z = Lib.empty in
  let f a = [%interact] in
  print_endline "hello!";
  f 2;
  print_endline "goodbye!"