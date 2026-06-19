module smarthome::Syntax

import lang::std::Layout;

lexical IdentLexical =  [a-zA-Z][a-zA-Z0-9_]* !>> [a-zA-Z0-9_];
syntax Ident = IdentLexical \ Reserved;

lexical Natural = [0-9]+ !>> [0-9];
lexical String = string: "\"" Char* "\"";
lexical Char = "\\" ![] | ![\\];

extend  lang::std::Layout;

keyword Reserved
= "if"
| "then"
| "else"
| "while"
| "do"
| "end"
| "let"
| "return"
| "send"
| "true"
| "false"
| "and"
| "or"
| "not"
| "int"
| "bool"
| "str"
| "list"
| "map"
| "tuple"
| "continue"
| "break"
;

start syntax System
= "{"
  "components" ":" "[" ({Component ","}+ ",")? "]" ","
  "connections" ":" "[" ({Connection ","}+ ",")? "]" ","
  ("types" ":" "[" ({EnumDef ","}+ ",")? "]")?
"}";

syntax EnumDef
= "enum" Ident ("\<" Type "\>")? "{"
  ({EnumValueDef ","}+ ",")?
"}";

syntax EnumValueDef = Ident | Ident "=" Exp;

syntax Connection
= "{" ConnectionSource "," ConnectionTarget "}"
;

syntax ConnectionSource
= "source" "(" Ident "," Ident ")"
| "source" "(" "http_json" "(" String ")" ")"
;
syntax ConnectionTarget
= "target" "(" Ident "," Ident ")"
| "target" "(" "http_json" "(" String ")" ")"
;

syntax Component = Ident ":" "{" "[" Port* "]" "," FSM "}";

syntax Port = "port" "(" Ident "," Type ")" ",";

syntax FSM = "{" States "," Initial "," ({Transition ","}+ ",")? "}";

syntax States = "states" ":" "[" ({StateDecl ","}+ ",")? "]";

syntax StateDecl = Ident "(" {IdentWithType ","}* ")";

syntax Initial = "initial" ":" StateCon;

syntax Transition = "transition" "("
Ident "-\>" Ident ","
OnEvent ","
Condition?
"action" ":" Func
")";

syntax Condition = "condition" ":" Func ",";

syntax OnEvent
= "(" Ident "," Exp ")"
| Ident
;

syntax Func
= func: "(" {IdentOrIdentWithType ","}* ")" FuncBody
| "(" {IdentOrIdentWithType ","}* ")" "-\>" Type "=" FuncBody;

syntax FuncBody
= "=" Exp // Desugar to { return exp; }
| "{" Statement* "}"
;

syntax IdentWithType = Ident ":" Type;
syntax IdentOrIdentWithType = Ident | IdentWithType;

syntax Type =
| integer_t: "int"
| boolean_t: "bool"
| string_t: "str"
| \map_t: "map" "[" Type "," Type "]"
| \list_t: "list" "[" Type "]"
| \tuple_t: "tuple" "[" {Type ","}* "]"
| \enum: Ident
;

syntax Primitive
= integer: Natural
| string: String
| boolean: "true"
| boolean: "false"
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
| stateCon: StateCon
| lvalue: LValue
// | call: Ident "(" {Exp ","}* ")"
> right not: "not" Exp
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
> non-assoc (
    non-assoc eq: Exp "==" Exp
  | non-assoc neq: Exp "!=" Exp
)
> left and: Exp "and" Exp
> left or: Exp "or" Exp
;

syntax StateCon = Ident "(" {Exp ","}* ")";

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
> send: "send" "(" {Exp ","}* ")" ";"
;
