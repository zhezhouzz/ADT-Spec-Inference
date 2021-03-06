module Ast = Language.SpecAst
module Value = Pred.Value
module Axiom = Inference.AxiomSyn;;
module Spec = Inference.SpecSyn;;
module S = Solver;;

open Ast
open Utils
open Z3
open Printf
module SE = E.SE
module T = Tp.Tp
module V = Pred.Value
open Language.Helper
open Frontend.Fast.Fast
;;

let time f x =
  let t = Sys.time() in
  let fx = f x in
  let delta = (Sys.time() -. t) in
  fx, delta

let get_head dttp =
  match dttp with
  | T.IntList -> "list.dfy.text", "List"
  | T.IntTree -> "tree.dfy.text", "Tree"
  | T.IntTreeI -> "labeled_treei.dfy.text", "LabeledTree"
  | T.IntTreeB -> "labeled_treeb.dfy.text", "LabeledTree"
  | _ -> raise @@ UndefExn "get_head"

let read_whole_file filename =
  let ch = open_in filename in
  let s = really_input_string ch (in_channel_length ch) in
  close_in ch;
  s

let axiom_eq ctx ax1 ax2 =
  match ax1, ax2 with
  | Some (_, ax1),  Some (_, ax2) ->
    let q =
      Z3.Boolean.mk_not ctx
        (Z3.Boolean.mk_iff ctx
           (E.forallformula_to_z3 ctx ax1) (E.forallformula_to_z3 ctx ax2)) in
    (match S.check ctx q with
     | true, _ -> (printf "axioms are eq"; true)
     | _, _ -> (printf "axioms are not eq"; false)
    )
  | _, _ -> raise @@ InterExn "axioms cannot be compare"


let to_verifier name axioms =
  let dttps, axioms = List.split @@ List.filter_map (fun x -> x) axioms in
  match dttps with
  | [] -> ()
  | dttp :: t ->
    if List.exists (fun x -> not (T.eq x dttp)) t
    then raise @@ TestFailedException "wrong dt"
    else
      let path = (Sys.getenv "DUNE_ROOT") ^ "/lemma_verifier/" in
      let headfile, dtname = get_head dttp in
      let headfile = path ^ headfile in
      let methods =
        List.fold_left (fun str axiom ->
            let numX = List.length (fst axiom) - 1 in
            let args = List.fold_left (fun r s -> r^s) "" @@
              List.init numX (fun i -> sprintf ", u_%i:a" i) in
            sprintf "%sghost method %s<a>(dt: %s<a>%s)
  ensures %s;{}\n" str (Renaming.unique "axiom") dtname args (E.layout (snd axiom))
          ) "" axioms
      in
      let outfile = sprintf "%s%s.dfy" path name in
      let head = read_whole_file headfile in
      let oc = open_out outfile in
      fprintf oc "%s\n%s" head methods;close_out oc

let record_stat stat time_delta name subname =
  let filename = "stat" in
  let entry = Axiom.make_stat_entry stat in
  let path = (Sys.getenv "DUNE_ROOT") ^ "/stat_ouput/" in
  let outfile = sprintf "%s%s.stat" path filename in
  let oc = open_out_gen [Open_append; Open_creat] 0o666 outfile in
  fprintf oc "%s-%s & %s & %.2f\\\\ \\hline \n" name subname (Axiom.layout_entry entry) time_delta;
  close_out oc

let print_vc_spec vc spec_tab =
  let _ = printf "#### vc\n\n```\n%s\n```\n\n#### specs\n" (vc_layout vc) in
  let _ = StrMap.iter (fun name spec ->
      printf "##### %s\n\n```\n%s\n```\n\n" name (layout_spec_entry name spec)) spec_tab in
  ()

let counter = ref 1

let printf_assertion spec_tab names =
  List.iter (fun name ->
      let spec = StrMap.find "printf_assertion" spec_tab name in
      printf "#### assertion-%i\n\n```\n%s\n```\n\n" (!counter) (layout_spec_entry name spec)
    ) names

let assertion ?(startX=1) ?(maxX=3) ctx vc spec_tab preds bpreds sampledata bound expected filename name  =
  let axiom, time_delta = time
    (fun _ ->
       Axiom.infer ~ctx:ctx ~vc:vc ~spectable:spec_tab ~preds:preds ~bpreds:bpreds
         ~startX:startX ~maxX:maxX ~sampledata:sampledata ~samplebound:bound) () in
  match axiom, expected with
  | (_, None), false -> printf "connot infer axiom\n"; None
  | (stat, Some (dttp, axiom)), true ->
    let _ = record_stat stat time_delta filename name in
    let _ = printf "#### lemma-%i\n\n```\n%s\n```\n\n"
        (!counter) (E.pretty_layout_forallformula axiom) in
    let _ = counter:= (!counter) + 1 in
    Some (dttp, axiom)

  | _ -> raise @@ InterExn "bench: wrong result"

let init () =
  let _ = Random.init 0 in
  let ctx =
    Z3.mk_context [("model", "true"); ("proof", "false"); ("timeout", "19999")] in
  ctx

let spec_tab_add spec_tab {name;intps;outtps;prog} =
  StrMap.add name (Spec.infer ~progtp:(intps,outtps) ~prog:prog) spec_tab

let register spec_tab {name;intps;outtps;prog} =
  let spec_tab = spec_tab_add spec_tab {name;intps;outtps;prog} in
  spec_tab, fun args -> SpecApply (name, args)

let make_lets l body =
  List.fold_right (fun (names, es) body ->
      Let(names, es, body)
    ) l body
