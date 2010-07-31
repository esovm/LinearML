open Utils

type id = Nast.id
type pstring = Nast.pstring

type program = module_ list

and module_ = {
    md_id: id ;
    md_decls: Neast.decl list ;
    md_defs: def list ;
  }

and type_expr = Neast.type_expr
and type_expr_list = Neast.type_expr_list

and def = id * pat * tuple

and pat = type_expr_list * pat_tuple list
and pat_tuple = pat_el list
and pat_el = type_expr * pat_
and pat_ = 
  | Pany 
  | Pid of id
  | Pvalue of value
  | Pvariant of id * pat
  | Precord of pat_field list

and pat_field = Pos.t * pat_field_
and pat_field_ = 
  | PFany
  | PFid of id 
  | PField of id * pat

and tuple = type_expr_list * tuple_pos list
and tuple_pos = type_expr_list * expr_
and expr = type_expr * expr_
and expr_ = 
  | Eid of id
  | Evalue of value
  | Evariant of id * tuple
  | Ebinop of Ast.bop * expr * expr
  | Euop of Ast.uop * expr
  | Erecord of (id * tuple) list 
  | Efield of expr * id 
  | Ematch of tuple * (pat * tuple) list
  | Elet of pat * tuple * tuple
  | Eif of expr * tuple * tuple
  | Eapply of id * tuple

and value = Nast.value

module FreeVars = struct

  let rec pat s (_, ptl) = List.fold_left pat_tuple s ptl 
  and pat_tuple s pl = List.fold_left pat_el s pl
  and pat_el s (_, p) = pat_ s p
  and pat_ s = function
    | Pvalue _ 
    | Pany -> s
    | Pid (_, x) -> ISet.add x s 
    | Pvariant (_, p) -> pat s p 
    | Precord pfl -> List.fold_left pat_field s pfl 

  and pat_field s (_, pf) = pat_field_ s pf
  and pat_field_ s = function
    | PFany -> s
    | PFid (_, x) -> ISet.add x s
    | PField (_, p) -> pat s p

  let pat p = pat ISet.empty p

end

module Rename = struct

  let id t (p, x) = 
    p, try IMap.find x t with Not_found -> x
	
  let rec module_ t md = 
    let defs = List.map (def t) md.md_defs in
    { md with md_defs = defs }
      
  and def t (x, pa, e) = id t x, pa, tuple t e
      
  and tuple t (ty, tpl) = ty, List.map (tuple_pos t) tpl
  and tuple_pos t (tyl, e) = tyl, expr_ t e
  and expr t (ty, e) = ty, expr_ t e
  and expr_ t = function
    | Eid x -> Eid (id t x)
    | Evalue _ as v -> v
    | Evariant (x, e) -> Evariant (x, tuple t e)
    | Ebinop (bop, e1, e2) -> Ebinop (bop, expr t e1, expr t e2)
    | Euop (uop, e1) -> Euop (uop, expr t e1)
    | Erecord fdl -> Erecord (List.map (field t) fdl)
    | Efield (e, x) -> Efield (expr t e, x) 
    | Ematch (e, al) -> Ematch (tuple t e, List.map (action t) al)
    | Elet (p, e1, e2) -> Elet (p, tuple t e1, tuple t e2)
    | Eif (e1, e2, e3) -> Eif (expr t e1, tuple t e2, tuple t e3)
    | Eapply (x, e) -> Eapply (x, tuple t e)
	  
  and field t (x, e) = x, tuple t e
  and action t (p, e) = p, tuple t e

end

module Fresh = struct

  let new_id = Ident.fresh

  let id t (p, x) = 
    p, try IMap.find x t with Not_found -> x

  let rec def ((p, x), pa, e) = 
    let y = new_id x in
    let t = IMap.add x y IMap.empty in
    let t = fresh_pat t pa in
    let pa = pat t pa in
    let e = tuple t e in
    (p, y), pa, e

  and fresh_pat t pa = 
    let fv = FreeVars.pat pa in
    ISet.fold (fun x acc -> IMap.add x (new_id x) acc) fv t

  and pat t (tyl, ptl) = tyl, List.map (pat_tuple t) ptl
  and pat_tuple t pel = List.map (pat_el t) pel 
  and pat_el t (ty, p) = ty, pat_ t p 
  and pat_ t = function
  | Pvalue _
  | Pany as x -> x
  | Pid x -> Pid (id t x) 
  | Pvariant (x, p) -> Pvariant (x, pat t p)
  | Precord pfl -> Precord (List.map (pat_field t) pfl) 

  and pat_field t (p, pf) = p, pat_field_ t pf
  and pat_field_ t = function
    | PFany -> PFany
    | PFid x -> PFid (id t x)
    | PField (x, p) -> PField (x, pat t p)

  and tuple t (tyl, tpl) = tyl, List.map (tuple_pos t) tpl 
  and tuple_pos t (tyl, e) = tyl, expr_ t e
  and expr t (ty, e) = ty, expr_ t e
  and expr_ t = function
  | Eid x -> Eid (id t x)
  | Evalue _ as v -> v
  | Evariant (x, e) -> Evariant (x, tuple t e)
  | Ebinop (bop, e1, e2) -> Ebinop (bop, expr t e1, expr t e2) 
  | Euop (uop, e) -> Euop (uop, expr t e)
  | Erecord fdl -> Erecord (List.map (field t) fdl)
  | Efield (e, x) -> Efield (expr t e, x) 
  | Ematch (e, pal) -> Ematch (tuple t e, List.map (action t) pal)
  | Elet (p, e1, e2) -> 
      let t = fresh_pat t p in
      let p = pat t p in
      Elet (p, tuple t e1, tuple t e2) 

  | Eif (e1, e2, e3) -> Eif (expr t e1, tuple t e2, tuple t e3)
  | Eapply (x, e) -> Eapply (id t x, e) 

  and field t (x, e) = x, tuple t e
      
  and action t (p, e) = 
    let t = fresh_pat t p in
    let p = pat t p in
    p, tuple t e

end
