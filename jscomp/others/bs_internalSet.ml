
module N = Bs_internalAVLset
module B =  Bs_Bag
module A = Bs_Array
type ('elt, 'id) t0 = ('elt, 'id) N.t0 

type ('elt, 'id)enumeration = 
  ('elt, 'id) N.enumeration0 
=
    End 
  | More of 'elt * ('elt, 'id) t0 * ('elt, 'id) enumeration


(* here we relies on reference transparence
   address equality means everything equal across time
   no need to call [bal] again
*)  
let rec add0 ~cmp (t : _ t0) x  : _ t0 =
  match N.toOpt t with 
    None -> N.(return @@ node ~left:empty ~right:empty ~key:x  ~h:1)
  | Some nt ->
    let k = N.key nt in 
    let c = (Bs_Cmp.getCmp cmp) x k [@bs] in
    if c = 0 then t else
      let l,r = N.(left nt, right nt) in 
      if c < 0 then 
        let ll = add0 ~cmp l x in 
        if ll == l then t 
        else N.bal ll k r 
      else 
        let rr = add0 ~cmp r x in 
        if rr == r then t 
        else N.bal l k rr 


(* Splitting.  split x s returns a triple (l, present, r) where
    - l is the set of elements of s that are < x
    - r is the set of elements of s that are > x
    - present is false if s contains no element equal to x,
      or true if s contains an element equal to x. *)
let rec splitAux ~cmp (n : _ N.node) x : _ * bool * _ =   
  let l,v,r = N.(left n , key n, right n) in  
  let c = (Bs_Cmp.getCmp cmp) x v [@bs] in
  if c = 0 then (l, true, r)
  else if c < 0 then
    match N.toOpt l with 
    | None -> 
      N.(empty , false, return n)
    | Some l -> 
      let (ll, pres, rl) = splitAux ~cmp  l x in (ll, pres, N.join rl v r)
  else
    match N.toOpt r with 
    | None ->
      N.(return n, false, empty)
    | Some r -> 
      let (lr, pres, rr) = splitAux ~cmp  r x in (N.join l v lr, pres, rr)

let  split0 ~cmp  (t : _ t0) x : _ t0 * bool * _ t0 =
  match N.toOpt t with 
    None ->
    N.(empty, false, empty)
  | Some n ->
    splitAux ~cmp n x

let rec mem0 ~cmp  (t: _ t0) x =
  match  N.toOpt t with 
  | None -> false
  | Some n ->
    let v = N.key n in 
    let c = (Bs_Cmp.getCmp cmp) x v [@bs] in
    c = 0 || mem0 ~cmp (if c < 0 then N.left n else N.right n) x

let rec remove0 ~cmp (t : _ t0) x : _ t0 = 
  match N.toOpt t with 
    None -> t
  | Some n  ->
    let l,v,r = N.(left n , key n, right n) in 
    let c = (Bs_Cmp.getCmp cmp) x v [@bs] in
    if c = 0 then N.merge l r else
    if c < 0 then 
      let ll = remove0 ~cmp  l x in 
      if ll == l then t
      else N.bal ll v r 
    else
      let rr = remove0 ~cmp  r x in 
      if rr == r then t  
      else N.bal l v rr

let addArray0 ~cmp  h arr =   
  let len = A.length arr in 
  let v = ref h in  
  for i = 0 to len - 1 do 
    let key = A.unsafe_get arr i in 
    v := add0 !v  ~cmp key 
  done ;
  !v 

let removeArray0 h arr ~cmp = 
  let len = A.length arr in 
  let v = ref h in  
  for i = 0 to len - 1 do 
    let key = A.unsafe_get arr i in 
    v := remove0 !v  ~cmp key 
  done ;
  !v 

(** FIXME: provide a [splitAux] which returns a tuple of two instead *)      
let rec union0 ~cmp (s1 : _ t0) (s2 : _ t0) : _ t0=
  match N.(toOpt s1, toOpt s2) with
    (None, _) -> s2
  | (_, None) -> s1
  | Some n1, Some n2 ->
    let h1, h2 = N.(h n1 , h n2) in                 
    if h1 >= h2 then
      if h2 = 1 then add0 ~cmp s1 (N.key n2)  else begin
        let l1, v1, r1 = N.(left n1, key n1, right n1) in      
        let (l2, _, r2) = split0 ~cmp  s2 v1 in
        N.join (union0 ~cmp l1 l2) v1 (union0 ~cmp r1 r2)
      end
    else
    if h1 = 1 then add0 s2 ~cmp (N.key n1)  else begin
      let l2, v2, r2 = N.(left n2 , key n2, right n2) in 
      let (l1, _, r1) = split0 ~cmp s1 v2  in
      N.join (union0 ~cmp l1 l2) v2 (union0 ~cmp r1 r2)
    end

let rec inter0 ~cmp (s1 : _ t0) (s2 : _ t0) =
  match N.(toOpt s1, toOpt s2) with
    (None, _) -> s1
  | (_, None) -> s2
  | Some n1, Some n2 (* (Node(l1, v1, r1, _), t2) *) ->
    let l1,v1,r1 = N.(left n1, key n1, right n1) in  
    match splitAux ~cmp n2 v1 with
      (l2, false, r2) ->
      N.concat (inter0 ~cmp l1 l2) (inter0 ~cmp r1 r2)
    | (l2, true, r2) ->
      N.join (inter0 ~cmp l1 l2) v1 (inter0 ~cmp r1 r2)

let rec diff0 ~cmp s1 s2 =
  match N.(toOpt s1, toOpt s2) with
    (None, _) 
  | (_, None) -> s1
  | Some n1, Some n2 (* (Node(l1, v1, r1, _), t2) *) ->
    let l1,v1,r1 = N.(left n1, key n1, right n1) in
    match splitAux ~cmp n2 v1  with
      (l2, false, r2) ->
      N.join (diff0 ~cmp l1 l2) v1 (diff0 ~cmp r1 r2)
    | (l2, true, r2) ->
      N.concat (diff0 ~cmp l1 l2) (diff0 ~cmp r1 r2)



let rec compare_aux ~cmp e1 e2 =
  match (e1, e2) with
    (End, End) -> 0
  | (End, _)  -> -1
  | (_, End) -> 1
  | (More(v1, r1, e1), More(v2, r2, e2)) ->
    let c = (Bs_Cmp.getCmp cmp) v1 v2 [@bs] in
    if c <> 0
    then c
    else compare_aux ~cmp (N.cons_enum r1 e1) (N.cons_enum r2 e2)

let cmp0 ~cmp s1 s2 =
  compare_aux ~cmp (N.cons_enum s1 End) (N.cons_enum s2 End)

let eq0 ~cmp s1 s2 =
  cmp0 ~cmp s1 s2 = 0

let rec subset0 ~cmp (s1 : _ t0) (s2 : _ t0) =
  match N.(toOpt s1, toOpt s2) with
    None, _ ->
    true
  | _, None ->
    false
  | Some t1 , Some t2 (* Node (l1, v1, r1, _), (Node (l2, v2, r2, _) as t2) *) ->
    let l1,v1,r1 = N.(left t1, key t1, right t1) in  
    let l2,v2,r2 = N.(left t2, key t2, right t2) in 
    let c = (Bs_Cmp.getCmp cmp) v1 v2 [@bs] in
    if c = 0 then
      subset0 ~cmp l1 l2 && subset0 ~cmp r1 r2
    else if c < 0 then
      subset0 ~cmp N.(return @@ node ~left:l1 ~key:v1 ~right:empty ~h:0) l2 && subset0 ~cmp r1 s2
    else
      subset0 ~cmp N.(return @@ node ~left:empty ~key:v1 ~right:r1 ~h:0) r2 && subset0 ~cmp l1 s2

let rec findOpt0 ~cmp (n : _ t0) x = 
  match N.toOpt n with 
    None -> None
  | Some t (* Node(l, v, r, _) *) ->
    let v = N.key t in 
    let c = (Bs_Cmp.getCmp cmp) x v [@bs] in
    if c = 0 then Some v
    else findOpt0 ~cmp  (if c < 0 then N.left t else N.right t) x


let rec findNull0 ~cmp (n : _ t0) x =
  match N.toOpt n with 
    None -> Js.null
  | Some t (* Node(l, v, r, _) *) ->
    let v = N.key t in 
    let c = (Bs_Cmp.getCmp cmp) x v [@bs] in
    if c = 0 then  N.return v
    else findNull0 ~cmp  (if c < 0 then N.left t else N.right t) x 



let rec addMutate ~cmp (t : _ t0) x =   
  match N.toOpt t with 
  | None -> N.(return @@ node ~left:empty ~right:empty ~key:x ~h:1)
  | Some nt -> 
    let k = N.key nt in 
    let  c = (Bs_Cmp.getCmp cmp) x k [@bs] in  
    if c = 0 then t 
    else
      let l, r = N.(left nt, right nt) in 
      (if c < 0 then                   
         let ll = addMutate ~cmp l x in
         N.leftSet nt ll
       else   
         N.rightSet nt (addMutate ~cmp r x);
      );
      N.return (N.balMutate nt)

let rec removeMutateAux ~cmp nt x = 
  let k = N.key nt in 
  let c = (Bs_Cmp.getCmp cmp) x k [@bs] in 
  if c = 0 then 
    let l,r = N.(left nt, right nt) in       
    match N.(toOpt l, toOpt r) with 
    | Some _,  Some nr ->  
      N.rightSet nt (N.removeMinAuxMutateWithRoot nt nr);
      N.return (N.balMutate nt)
    | None, Some _ ->
      r  
    | (Some _ | None ), None ->  l 
  else 
    begin 
      if c < 0 then 
        match N.toOpt (N.left nt) with         
        | None -> N.return nt 
        | Some l ->
          N.leftSet nt (removeMutateAux ~cmp l x );
          N.return (N.balMutate nt)
      else 
        match N.toOpt (N.right nt) with 
        | None -> N.return nt 
        | Some r -> 
          N.rightSet nt (removeMutateAux ~cmp r x);
          N.return (N.balMutate nt)
    end



let rec sortedLengthAux ~cmp (xs : _ array) prec acc len =    
  if  acc >= len then acc 
  else 
    let v = A.unsafe_get xs acc in 
    if (Bs_Cmp.getCmp cmp) v  prec [@bs] >= 0 then 
      sortedLengthAux ~cmp xs v (acc + 1) len 
    else acc    

let ofArray0 ~cmp (xs : _ array) =   
  let len = A.length xs in 
  if len = 0 then N.empty0
  else
    let next = sortedLengthAux ~cmp xs (A.unsafe_get xs 0) 1 len in 
    let result  = ref (N.ofSortedArrayAux  xs 0 next) in 
    for i = next to len - 1 do 
      result := addMutate ~cmp !result (A.unsafe_get xs i) 
    done ;
    !result     


let addArrayMutate (t : _ t0) xs ~cmp =     
  let v = ref t in 
  for i = 0 to A.length xs - 1 do 
    v := addMutate !v (A.unsafe_get xs i)  ~cmp
  done; 
  !v 


let rec addMutateCheckAux  (t : _ t0) x added ~cmp  =   
  match N.toOpt t with 
  | None -> 
    added := true;
    N.(return @@ node ~left:empty ~right:empty ~key:x ~h:1)
  | Some nt -> 
    let k = N.key nt in 
    let  c = (Bs_Cmp.getCmp cmp) x k [@bs] in  
    if c = 0 then t 
    else
      let l, r = N.(left nt, right nt) in 
      (if c < 0 then                   
         let ll = addMutateCheckAux ~cmp l x added in
         N.leftSet nt ll
       else   
         N.rightSet nt (addMutateCheckAux ~cmp r x added );
      );
      N.return (N.balMutate nt)


let rec removeArrayMutateAux t xs i len ~cmp  =  
  if i < len then 
    let ele = A.unsafe_get xs i in 
    let u = removeMutateAux t ele ~cmp in 
    match N.toOpt u with 
    | None -> N.empty0
    | Some t -> removeArrayMutateAux t xs (i+1) len ~cmp 
  else N.return t    

let removeArrayMutate (t : _ t0) xs ~cmp =
  match N.toOpt t with 
  | None -> t
  | Some nt -> 
    let len = A.length xs in 
    removeArrayMutateAux nt xs 0 len ~cmp 

let rec removeMutateCheckAux  nt x removed ~cmp= 
  let k = N.key nt in 
  let c = (Bs_Cmp.getCmp cmp) x k [@bs] in 
  if c = 0 then 
    let () = removed := true in  
    let l,r = N.(left nt, right nt) in       
    match N.(toOpt l, toOpt r) with 
    | Some _,  Some nr ->  
      N.rightSet nt (N.removeMinAuxMutateWithRoot nt nr);
      N.return (N.balMutate nt)
    | None, Some _ ->
      r  
    | (Some _ | None ), None ->  l 
  else 
    begin 
      if c < 0 then 
        match N.toOpt (N.left nt) with         
        | None -> N.return nt 
        | Some l ->
          N.leftSet nt (removeMutateCheckAux ~cmp l x removed);
          N.return (N.balMutate nt)
      else 
        match N.toOpt (N.right nt) with 
        | None -> N.return nt 
        | Some r -> 
          N.rightSet nt (removeMutateCheckAux ~cmp r x removed);
          N.return (N.balMutate nt)
    end