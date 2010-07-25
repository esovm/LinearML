open Lexing 

let o = output_string stderr 

let parse fn = 
  Pos.file := fn ;
  let ic = open_in fn in
  let lb = Lexing.from_channel ic in
  try Parser.program Lexer.token lb
  with 
  | Lexer.Lexical_error _ -> Error.lexing_error lb 
  | Parsing.Parse_error -> Error.syntax_error lb 

(*let rec loop env = 
  output_string stdout "$ " ; flush stdout ;
  let s = read_line() in
  let lb = Lexing.from_string s in
  let p = Parser.expr Lexer.token lb in
  let x = Eval.expr env p in
  output_string stdout (AstPp.expr x) ;
  output_char stdout '\n' ;
  flush stdout ;
  loop env

let _ = 
  let file = "/home/pika/linearML/test/test.ml" in
  let p = parse file in
  let env = Eval.program p in
  loop env 
*)
    
let _ = 
  let last_arg = (Array.length Sys.argv) - 1  in
  let module_l = ref [] in
  for i = 1 to last_arg do
    let new_module = parse Sys.argv.(i) in
    Printf.printf "Done parsing\n" ; flush stdout ;
    let nast = Naming.program new_module in
    Printf.printf "Done naming\n" ; flush stdout ;
    NastCheck.program nast ;
    Printf.printf "Done nastcheck\n" ; flush stdout ;
    let nast = NastExtractFuns.program nast in
    Printf.printf "Done Fun extraction\n" ; flush stdout ;
    let neast = NastExpand.program nast in
    Printf.printf "Done nastExpand\n" ; flush stdout ;
    let _ = Typing.program neast in
(*    let tast = Typing.program nast in *)
    module_l := new_module :: !module_l 
  done ;
  !module_l

