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
