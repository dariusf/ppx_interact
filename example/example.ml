let succ x = x + 1
let a = 1

let () =
  let d = Lib.info in
  let b = 2 in
  [%interact];
  let c = 3 in
  [%interact]
