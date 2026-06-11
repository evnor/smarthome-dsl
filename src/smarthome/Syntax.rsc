module smarthome::Syntax

lexical Ident =  [a-zA-Z][a-zA-Z0-9]* !>> [a-zA-Z0-9] \ Reserved;

lexical Natural = [0-9]+ !>> [0-9];
lexical String = string: "\"" Char* "\"";
lexical Char = "\\" ![] | ![\\];

lexical LAYOUT = [\ \t\n\r];

layout LAYOUTLIST = LAYOUT*  !>> [\ \t\n\r] ;

keyword Reserved
= "if"
| "else"
| "while"
| "do"
| "end"
| "int"
| "str"
| "list"
| "map"
| "tuple"
| "continue"
| "break"
;

start syntax System
  = "{" Func "}";

syntax Func
= func: "(" {IdentWithType ","}* ")" FuncBody
| "(" {IdentWithType ","}* ")" "-\>" Type "=" FuncBody;

syntax FuncBody
= "=" Exp // Desugar to { return exp; }
| "{" Statement* "}"
;

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

syntax LValue
= var: Ident
| left index: LValue "[" Exp "]"
| left field: LValue "." Ident
;

syntax Exp 
= bracket "(" Exp ")"
| primCon: Primitive
| lvalue: LValue
// | call: Ident "(" {Exp ","}* ")"
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
;

syntax Statement
= declStat: "let" LValue lval ":" Type tp ";"
| assignStat: LValue lval "=" Exp rval ";"
| "let" LValue lval ":" Type tp "=" Exp rval ";" // decl+assign
| "let" LValue lval "=" Exp rval ";" // decl+assign (inferred type)

| ifElseStat: "if" Exp cond "then" Statement* ifpart "else" Statement* elsepart "end"
| whileStat: "while" Exp cond "do" Statement* body "end"
| \continue: "continue" ";"
| \break: "break" ";"
| \return: "return" Exp? ";"
;