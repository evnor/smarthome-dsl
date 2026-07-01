module smarthome::CST2AST

import String;
import ParseTree;

import smarthome::Syntax;
import smarthome::AST;

public smarthome::AST::System cst2ast(start[System] s) {
  return cst2ast(s.top);
}

public smarthome::AST::System cst2ast(tree:(System) `{ components: [ <{Component ","}+ components>, ], connections: [ <{Connection ","}+ connections>, ], types: [ <{EnumDef ","}+ enumDefs>, ] }`) {
  return system([cst2ast(c) | c <- components], [cst2ast(c) | c <- connections], [cst2ast(t) | t <- enumDefs])[src=tree.src];
}

public smarthome::AST::System cst2ast(tree:(System) `{ components: [ <{Component ","}+ components>, ], connections: [ <{Connection ","}+ connections>, ], }`) {
  return system([cst2ast(c) | c <- components], [cst2ast(c) | c <- connections], [])[src=tree.src];
}

EnumDef cst2ast(tree:(EnumDef) `enum <Ident id> { <{EnumValueDef ","}+ values>, }`) {
  return enumDef(cst2ast(id), integerT(), [cst2ast(v) | v <- values])[src=tree.src];
}

EnumDef cst2ast(tree:(EnumDef) `enum <Ident id> { }`) {
  return enumDef(cst2ast(id), integerT(), [])[src=tree.src];
}

EnumDef cst2ast(tree:(EnumDef) `enum <Ident id>\< <Type tp> \>{ <{EnumValueDef ","}+ values>, }`) {
  return enumDef(cst2ast(id), cst2ast(tp), [cst2ast(v) | v <- values])[src=tree.src];
}

EnumDef cst2ast(tree:(EnumDef) `enum <Ident id>\< <Type tp> \>{ }`) {
  return enumDef(cst2ast(id), cst2ast(tp), [])[src=tree.src];
}

EnumValueDef cst2ast(tree:(EnumValueDef) `<Ident id>`) {
  return enumValueDef(cst2ast(id), none())[src=tree.src];
}

EnumValueDef cst2ast(tree:(EnumValueDef) `<Ident id> = <Exp exp>`) {
  return enumValueDef(cst2ast(id), some(cst2ast(exp)))[src=tree.src];
}

Component cst2ast(tree:(Component) `<Ident id>: { [ <Port* ports> ], <FSM fsm> }`) {
  return component(cst2ast(id), [cst2ast(p) | p <- ports], cst2ast(fsm))[src=tree.src];
}

Port cst2ast(tree:(Port) `port(<Ident id>, <Type tp>),`) {
  return port(cst2ast(id), cst2ast(tp))[src=tree.src];
}

Connection cst2ast(tree:(Connection) `{ <ConnectionSource source>, <ConnectionTarget target> }`) {
  switch (<cst2ast(source), cst2ast(target)>) {
    case <PortID sourcePort, PortID targetPort>:
      return internalConnection(sourcePort, targetPort)[src=tree.src];
    case <ExternalSourcePort externalSource, PortID targetPort>:
      return externalSourceConnection(externalSource, targetPort)[src=tree.src];
    case <PortID sourcePort, ExternalTargetPort externalTarget>:
      return externalTargetConnection(sourcePort, externalTarget)[src=tree.src];
  }

  throw "Connection cannot have both an external source and an external target";
}

value cst2ast(tree:(ConnectionSource) `source(<Ident component>, <Ident port>)`) {
  return portID(cst2ast(component), cst2ast(port))[src=tree.src];
}

value cst2ast(tree:(ConnectionSource) `source(http_json(<String uri>))`) {
  return httpJson(unquote("<uri>"))[src=tree.src];
}

value cst2ast(tree:(ConnectionTarget) `target(<Ident component>, <Ident port>)`) {
  return portID(cst2ast(component), cst2ast(port))[src=tree.src];
}

value cst2ast(tree:(ConnectionTarget) `target(http_json(<String uri>))`) {
  return httpJson(unquote("<uri>"))[src=tree.src];
}

FSM cst2ast(tree:(FSM) `{ <States states>, <Initial initial>, <{Transition ","}+ transitions>, }`) {
  return transitionList(cst2ast(states), cst2ast(initial), [cst2ast(t) | t <- transitions])[src=tree.src];
}

list[State] cst2ast((States) `states: [ <{StateDecl ","}+ states>, ]`) {
  return [cst2astStateDecl(s) | s <- states];
}

list[State] cst2ast((States) `states: [ ]`) {
  return [];
}

State cst2astStateDecl(tree:(StateDecl) `<Ident name>(<{IdentWithType ","}* fields>)`) {
  return state(cst2ast(name), [cst2ast(f) | f <- fields])[src=tree.src];
}

Exp cst2ast(tree:(Initial) `initial: <Exp initial>`) {
  return cst2ast(initial)[src=tree.src];
}

Transition cst2ast(tree:(Transition) `transition(<Ident source> -\> <Ident target>, <OnEvent event>, action: <Func action>)`) {
  State sourceState = state(cst2ast(source), [])[src=source.src];
  State targetState = state(cst2ast(target), [])[src=target.src];
  return transition(sourceState, targetState, cst2ast(event), alwaysTrue(), cst2ast(action))[src=tree.src];
}

Transition cst2ast(tree:(Transition) `transition(<Ident source> -\> <Ident target>, <OnEvent event>, <Condition condition>action: <Func action>)`) {
  State sourceState = state(cst2ast(source), []);
  State targetState = state(cst2ast(target), []);
  return transition(sourceState, targetState, cst2ast(event), cst2ast(condition), cst2ast(action))[src=tree.src];
}

Func cst2ast(tree:(Condition) `condition: <Func condition>,`) {
  return cst2ast(condition)[src=tree.src];
}

Event cst2ast(tree:(OnEvent) `<Ident port>`) {
  return anyMessageFromPort(cst2ast(port))[src=tree.src];
}

Event cst2ast(tree:(OnEvent) `(<Ident port>, <Exp payload>)`) {
  return specificMessageFromPort(cst2ast(payload), cst2ast(port))[src=tree.src];
}

Func cst2ast(tree:(Func) `(<{IdentOrIdentWithType ","}* params>) <FuncBody body>`) {
  return func([cst2astParam(p) | p <- params], cst2ast(body), inferredT())[src=tree.src];
}

Func cst2ast(tree:(Func) `(<{IdentOrIdentWithType ","}* params>) -\> <Type returnType> <FuncBody body>`) {
  return func([cst2astParam(p) | p <- params], cst2ast(body), cst2ast(returnType))[src=tree.src];
}

list[Statement] cst2ast((FuncBody) `= <Exp exp>`) {
  return [\return(cst2ast(exp))];
}

list[Statement] cst2ast((FuncBody) `{ <Statement* statements> }`) {
  return [cst2ast(s) | s <- statements];
}

tuple[Type, str] cst2astParam((IdentOrIdentWithType) `<Ident id>`) {
  return <inferredT(), cst2ast(id)>;
}

tuple[Type, str] cst2astParam((IdentOrIdentWithType) `<Ident id>: <Type tp>`) {
  return <cst2ast(tp), cst2ast(id)>;
}

tuple[str, Type] cst2ast((IdentWithType) `<Ident id>: <Type tp>`) {
  return <cst2ast(id), cst2ast(tp)>;
}

Statement cst2ast(tree:(Statement) `let <LValue lval>: <Type tp>;`) {
  return declStat(lvalueName(lval), cst2ast(tp))[src=tree.src];
}

Statement cst2ast(tree:(Statement) `<LValue lval> = <Exp rval>;`) {
  return smarthome::AST::assignStat(cst2ast(lval), cst2ast(rval))[src=tree.src];
}

Statement cst2ast(tree:(Statement) `let <LValue lval>: <Type tp> = <Exp rval>;`) {
  return declAssignStat(lvalueName(lval), cst2ast(tp), cst2ast(rval))[src=tree.src];
}

Statement cst2ast(tree:(Statement) `let <LValue lval> = <Exp rval>;`) {
  return declAssignStat(lvalueName(lval), inferredT(), cst2ast(rval))[src=tree.src];
}

Statement cst2ast(tree:(Statement) `if <Exp cond> then <Statement* ifpart> else <Statement* elsepart> end`) {
  return ifElseStat(cst2ast(cond), [cst2ast(s) | s <- ifpart], [cst2ast(s) | s <- elsepart])[src=tree.src];
}

Statement cst2ast(tree:(Statement) `if <Exp cond> then <Statement* ifpart> end`) {
  return ifElseStat(cst2ast(cond), [cst2ast(s) | s <- ifpart], [])[src=tree.src];
}

Statement cst2ast(tree:(Statement) `while <Exp cond> do <Statement* body> end`) {
  return whileStat(cst2ast(cond), [cst2ast(s) | s <- body])[src=tree.src];
}

Statement cst2ast(tree:(Statement) `continue;`) = smarthome::AST::\continue()[src=tree.src];

Statement cst2ast(tree:(Statement) `break;`) = smarthome::AST::\break()[src=tree.src];

Statement cst2ast(tree:(Statement) `return;`) = smarthome::AST::\return(smarthome::AST::primCon(smarthome::AST::\tuple([])))[src=tree.src];

Statement cst2ast(tree:(Statement) `return <Exp exp>;`) = \return(cst2ast(exp))[src=tree.src];

Statement cst2ast(tree:(Statement) `send(<{Exp ","}* params>);`) {
  return send([cst2ast(p) | p <- params])[src=tree.src];
}

LValue cst2ast(tree:(LValue) `<Ident id>`) = var(cst2ast(id))[src=tree.src];

LValue cst2ast(tree:(LValue) `<LValue lhs>[<Exp idx>]`) = smarthome::AST::index(cst2ast(lhs), cst2ast(idx))[src=tree.src];

LValue cst2ast(tree:(LValue) `<LValue lhs>.<Ident fieldName>`) = field(cst2ast(lhs), cst2ast(fieldName))[src=tree.src];

Exp cst2ast(tree:(Exp) `(<Exp exp>)`) = cst2ast(exp)[src=tree.src];

Exp cst2ast(tree:(Exp) `<Primitive primitive>`) = smarthome::AST::primCon(cst2ast(primitive))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Ident name>(<{Exp ","}* params>)`) = call(cst2ast(name), [cst2ast(p) | p <- params])[src=tree.src];

Exp cst2ast(tree:(Exp) `<LValue lval>`) = smarthome::AST::lvalue(cst2ast(lval))[src=tree.src];

Exp cst2ast(tree:(Exp) `not <Exp exp>`) = smarthome::AST::\not(cst2ast(exp))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> * <Exp rhs>`) = smarthome::AST::mul(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> / <Exp rhs>`) = smarthome::AST::div(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> + <Exp rhs>`) = smarthome::AST::add(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> - <Exp rhs>`) = smarthome::AST::sub(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> \> <Exp rhs>`) = smarthome::AST::gt(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> \< <Exp rhs>`) = smarthome::AST::lt(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> \>= <Exp rhs>`) = smarthome::AST::geq(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> \<= <Exp rhs>`) = smarthome::AST::leq(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> == <Exp rhs>`) = smarthome::AST::eq(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> != <Exp rhs>`) = smarthome::AST::neq(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> in <Exp rhs>`) = smarthome::AST::\in(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> and <Exp rhs>`) = smarthome::AST::\and(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Exp cst2ast(tree:(Exp) `<Exp lhs> or <Exp rhs>`) = smarthome::AST::\or(cst2ast(lhs), cst2ast(rhs))[src=tree.src];

Primitive cst2ast(tree:(Primitive) `<Natural n>`) = integer(toInt("<n>"))[src=tree.src];

Primitive cst2ast(tree:(Primitive) `<String s>`) = smarthome::AST::string(unquote("<s>"))[src=tree.src];

Primitive cst2ast(tree:(Primitive) `true`) = boolean(true)[src=tree.src];

Primitive cst2ast(tree:(Primitive) `false`) = boolean(false)[src=tree.src];

Primitive cst2ast(tree:(Primitive) `{ <{MapKeyValuePair ","}* pairs> }`) {
  return \map((k: v | <k, v> <- [cst2ast(p) | p <- pairs]))[src=tree.src];
}

Primitive cst2ast(tree:(Primitive) `[ <{Primitive ","}* values> ]`) {
  return smarthome::AST::\list([cst2ast(v) | v <- values])[src=tree.src];
}

Primitive cst2ast(tree:(Primitive) `(<{Primitive ","}* values>)`) {
  return \tuple([cst2ast(v) | v <- values])[src=tree.src];
}

tuple[str, Primitive] cst2ast((MapKeyValuePair) `<Primitive key> = <Primitive val>`) {
  return <primitiveKey(cst2ast(key)), cst2ast(val)>;
}

tuple[str, Primitive] cst2ast((MapKeyValuePair) `<Primitive key> = <Ident enumname> . <Ident valuename>`) {
  return <primitiveKey(cst2ast(key)), \enum(cst2ast(enumname), cst2ast(valuename))>;
}

Type cst2ast(tree:(Type) `int`) = integerT()[src=tree.src];

Type cst2ast(tree:(Type) `bool`) = booleanT()[src=tree.src];

Type cst2ast(tree:(Type) `str`) = stringT()[src=tree.src];

Type cst2ast(tree:(Type) `map[<Type keyType>, <Type valueType>]`) = \mapT(cst2ast(keyType), cst2ast(valueType))[src=tree.src];

Type cst2ast(tree:(Type) `list[<Type tp>]`) = \listT(cst2ast(tp))[src=tree.src];

Type cst2ast(tree:(Type) `tuple[<{Type ","}* types>]`) = \tupleT([cst2ast(t) | t <- types])[src=tree.src];

Type cst2ast(tree:(Type) `<Ident id>`) = namedT(cst2ast(id))[src=tree.src];

str cst2ast((Ident) `<IdentLexical id>`) = "<id>";

str lvalueName((LValue) `<Ident id>`) = cst2ast(id);

default str lvalueName(LValue lval) {
  throw "Only simple variable declarations are supported, got <lval>";
}

Func alwaysTrue() {
  return func([], [smarthome::AST::\return(smarthome::AST::primCon(boolean(true)))], booleanT());
}

str primitiveKey(integer(int i)) = "<i>";

str primitiveKey(string(str s)) = s;

str primitiveKey(boolean(bool b)) = "<b>";

default str primitiveKey(Primitive p) = "<p>";

str unquote(str s) {
  if (size(s) < 2) {
    return s;
  }

  return substring(s, 1, size(s) - 1);
}
