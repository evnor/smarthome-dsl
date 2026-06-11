module smarthome::Syntax

lexical Ident =  [a-zA-Z][a-zA-Z0-9]* !>> [a-zA-Z0-9];

lexical Natural = [0-9]+ !>> [0-9];
lexical String = string: "\"" Char* "\"";
lexical Char = "\\" ![] | ![\\];

lexical LAYOUT = [\ \t\n\r];

layout LAYOUTLIST = LAYOUT*  !>> [\ \t\n\r] ;

start syntax System
  = "{" Func "}";

syntax Func
= func: "(" {IdentWithType ","}* ")" "=" Exp
| "(" {IdentWithType ","}* ")" "-\>" Type "=" Exp;

syntax IdentWithType = Ident ":" Type | Ident;

syntax Type =
| integer_t: "int"
| string_t: "str"
| \map_t: "map" "[" Type "," Type "]"
| \list_t: "list" "[" Type "]"
| \tuple_t: "tuple" "[" {Type ","}* "]"
;

syntax Primitive
= integer: Natural
| string: String
| \map: "{" {MapKeyValuePair ","}* "}"
| \list: "[" Primitive* "]"
| \tuple: "(" {Primitive ","}* ")"
;

syntax MapKeyValuePair = Primitive "=" Primitive;

syntax Exp 
= err: "error" "(" String ")"
| let: "let" {Binding ","}* "in" Exp "end"
| cond: "if" Exp "then" Exp "else" Exp "end"
| bracket "(" Exp ")"
| var: Ident
| prim: Primitive
| call: Ident "(" {Exp ","}* ")"
> non-assoc (
    left mul: Exp "*" Exp 
  | non-assoc div: Exp "/" Exp
) 
> left (
    left add: Exp "+" Exp 
  | left sub: Exp "-" Exp
)
>
non-assoc (
    non-assoc gt: Exp "\>" Exp
  | non-assoc lt:  Exp "\<" Exp
  | non-assoc geq:  Exp "\>=" Exp
  | non-assoc leq:  Exp "\<=" Exp
)
>
right assign: Exp ":=" Exp
>
right seq: Exp ";" Exp
;

syntax Binding = binding: Ident "=" Exp;