#ifdef TYPE_INT
module I = Bs_internalMapInt
module S = Bs_SortInt
type key = int
#elif defined TYPE_STRING
module I = Bs_internalMapString
module S = Bs_SortString
type key = string
#else
  [%error "unknown type"]
#endif  
module N = Bs_internalAVLtree
module A = Bs_Array 




type 'a t = {
  mutable data : 'a I.t
} [@@bs.deriving abstract]


let empty () = t ~data:N.empty0      
let isEmpty m = N.isEmpty0 (data m)
let singleton k v = t ~data:(N.singleton0 k v)

let minKeyNull m = N.minKeyNull0 (data m)
let minKeyOpt m = N.minKeyOpt0 (data m)
let maxKeyNull m = N.maxKeyNull0 (data m)
let maxKeyOpt m = N.maxKeyOpt0 (data m)
let minKeyValueOpt m = N.minKVOpt0 (data m)
let minKeyValueNull m = N.minKVNull0 (data m)
let maxKeyValueOpt m = N.maxKVOpt0 (data m)
let maxKeyValueNull m = N.maxKVNull0 (data m)

let addDone (m : _ t) k v = 
  let old_data = data m in 
  let v = I.addMutate old_data k v in 
  if v != old_data then 
    dataSet m v 

let add (d : 'a t) (k : key) (v : 'a) : 'a t=  
  addDone d k v; 
  d
let iter d f = N.iter0 (data d) f     
let map d f = t ~data:(N.map0 (data d) f)
let mapi d f = t ~data:(N.mapi0 (data d) f) 
let fold d acc f  = N.fold0 (data d) acc f 
let forAll d f = N.forAll0 (data d) f 
let exists d f = N.exists0 (data d) f    

let length d = N.length0 (data d)
let toList d = N.toList0 (data d)
let toArray d = N.toArray0 (data d)
let keysToArray d = N.keysToArray0 (data d)
let valuesToArray d = N.valuesToArray0 (data d)
let checkInvariant d = N.checkInvariant (data d)
let mem d v = I.mem (data d) v 


let rec removeMutateAux nt (x : key)= 
  let k = N.key nt in 
  if x = k then 
    let l,r = N.(left nt, right nt) in       
    match N.(toOpt l, toOpt r) with 
    | Some _,  Some nr ->  
      N.rightSet nt (N.removeMinAuxWithRootMutate nt nr);
      N.return (N.balMutate nt)
    | None, Some _ ->
      r  
    | (Some _ | None ), None ->  l 
  else 
    begin 
      if x < k then 
        match N.toOpt (N.left nt) with         
        | None -> N.return nt 
        | Some l ->
          N.leftSet nt (removeMutateAux l x );
          N.return (N.balMutate nt)
      else 
        match N.toOpt (N.right nt) with 
        | None -> N.return nt 
        | Some r -> 
          N.rightSet nt (removeMutateAux r x);
          N.return (N.balMutate nt)
    end

let removeDone d v = 
  let oldRoot = data d in 
  match N.toOpt oldRoot with 
  | None -> ()
  | Some root -> 
    let newRoot = removeMutateAux root v in 
    if newRoot != oldRoot then 
      dataSet d newRoot   

let remove d v = 
  removeDone d v; 
  d 
  
let rec removeArrayMutateAux t xs i len   =  
  if i < len then 
    let ele = A.unsafe_get xs i in 
    let u = removeMutateAux t ele  in 
    match N.toOpt u with 
    | None -> N.empty0
    | Some t -> removeArrayMutateAux t xs (i+1) len 
  else N.return t    

let removeArrayDone (type elt) (type id) (d : _ t) xs =  
  let oldRoot = data d in 
  match N.toOpt oldRoot with 
  | None -> ()
  | Some nt -> 
    let len = A.length xs in 
    let newRoot = removeArrayMutateAux nt xs 0 len in 
    if newRoot != oldRoot then 
      dataSet d newRoot

let removeArray d xs =      
  removeArrayDone d xs; 
  d  

let cmp = I.cmp 
let eq = I.eq 


(* let split = I.split  *)
(* let merge = I.merge  *)


let ofArray xs = 
  t  ~data:(I.ofArray xs)

let cmp d0 d1 = 
  I.cmp (data d0) (data d1)
let eq d0 d1 = 
  I.eq (data d0) (data d1)
let getOpt d x = 
  I.findOpt (data d) x 
let getNull d x = I.findNull (data d) x 
let getWithDefault d x def = I.findWithDefault (data d) x def  
let getExn d x = I.findExn (data d) x 
