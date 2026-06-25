module smarthome::CST2AST

import String;

import smarthome::Syntax;
import smarthome::AST;

public smarthome::AST::System cst2ast(start[System] s) {
  return cst2ast(s.top);
}

public smarthome::AST::System cst2ast((System) `{ components: [ <{Component ","}+ components>, ], connections: [ <{Connection ","}+ connections>, ], types: [ <{EnumDef ","}+ enumDefs>, ] }`) {
  return system([cst2ast(c) | c <- components], [cst2ast(c) | c <- connections], [cst2ast(t) | t <- enumDefs]);
}

public smarthome::AST::System cst2ast((System) `{ components: [ <{Component ","}+ components>, ], connections: [ <{Connection ","}+ connections>, ], }`) {
  return system([cst2ast(c) | c <- components], [cst2ast(c) | c <- connections], []);
}

EnumDef cst2ast((EnumDef) `enum <Ident id> { <{EnumValueDef ","}+ values>, }`) {
  return enumDef(cst2ast(id), integerT(), [cst2ast(v) | v <- values]);
}

EnumDef cst2ast((EnumDef) `enum <Ident id> { }`) {
  return enumDef(cst2ast(id), integerT(), []);
}

EnumDef cst2ast((EnumDef) `enum <Ident id>\< <Type tp> \>{ <{EnumValueDef ","}+ values>, }`) {
  return enumDef(cst2ast(id), cst2ast(tp), [cst2ast(v) | v <- values]);
}

EnumDef cst2ast((EnumDef) `enum <Ident id>\< <Type tp> \>{ }`) {
  return enumDef(cst2ast(id), cst2ast(tp), []);
}

EnumValueDef cst2ast((EnumValueDef) `<Ident id>`) {
  return enumValueDef(cst2ast(id), none());
}

EnumValueDef cst2ast((EnumValueDef) `<Ident id> = <Exp exp>`) {
  return enumValueDef(cst2ast(id), some(cst2ast(exp)));
}

Component cst2ast((Component) `<Ident id>: { [ <Port* ports> ], <FSM fsm> }`) {
  return component(cst2ast(id), [cst2ast(p) | p <- ports], cst2ast(fsm));
}

Port cst2ast((Port) `port(<Ident id>, <Type tp>),`) {
  return port(cst2ast(id), cst2ast(tp));
}

Connection cst2ast((Connection) `{ <ConnectionSource source>, <ConnectionTarget target> }`) {
  switch (<cst2ast(source), cst2ast(target)>) {
    case <PortID sourcePort, PortID targetPort>:
      return internalConnection(sourcePort, targetPort);
    case <ExternalSourcePort externalSource, PortID targetPort>:
      return externalSourceConnection(externalSource, targetPort);
    case <PortID sourcePort, ExternalTargetPort externalTarget>:
      return externalTargetConnection(sourcePort, externalTarget);
  }

  throw "Connection cannot have both an external source and an external target";
}

value cst2ast((ConnectionSource) `source(<Ident component>, <Ident port>)`) {
  return portID(cst2ast(component), cst2ast(port));
}

value cst2ast((ConnectionSource) `source(http_json(<String uri>))`) {
  return httpJson(unquote("<uri>"));
}

value cst2ast((ConnectionTarget) `target(<Ident component>, <Ident port>)`) {
  return portID(cst2ast(component), cst2ast(port));
}

value cst2ast((ConnectionTarget) `target(http_json(<String uri>))`) {
  return httpJson(unquote("<uri>"));
}

FSM cst2ast((FSM) `{ <States states>, <Initial initial>, <{Transition ","}+ transitions>, }`) {
  return transitionList(cst2ast(states), cst2ast(initial), [cst2ast(t) | t <- transitions]);
}

list[State] cst2ast((States) `states: [ <{StateDecl ","}+ states>, ]`) {
  return [cst2astStateDecl(s) | s <- states];
}

list[State] cst2ast((States) `states: [ ]`) {
  return [];
}

State cst2astStateDecl((StateDecl) `<Ident name>(<{IdentWithType ","}* fields>)`) {
  return state(cst2ast(name), [cst2ast(f) | f <- fields]);
}

Exp cst2ast((Initial) `initial: <StateCon initial>`) {
  return cst2ast(initial);
}

Transition cst2ast((Transition) `transition(<Ident source> -\> <Ident target>, <OnEvent event>, action: <Func action>)`) {
  State sourceState = state(cst2ast(source), []);
  State targetState = state(cst2ast(target), []);
  return transition(sourceState, targetState, cst2ast(event), alwaysTrue(), cst2ast(action));
}

Transition cst2ast((Transition) `transition(<Ident source> -\> <Ident target>, <OnEvent event>, <Condition condition>action: <Func action>)`) {
  State sourceState = state(cst2ast(source), []);
  State targetState = state(cst2ast(target), []);
  return transition(sourceState, targetState, cst2ast(event), cst2ast(condition), cst2ast(action));
}

Func cst2ast((Condition) `condition: <Func condition>,`) {
  return cst2ast(condition);
}

Event cst2ast((OnEvent) `<Ident port>`) {
  return anyMessageFromPort(cst2ast(port));
}

Event cst2ast((OnEvent) `(<Ident port>, <Exp payload>)`) {
  return specificMessageFromPort(cst2ast(payload), cst2ast(port));
}

Func cst2ast((Func) `(<{IdentOrIdentWithType ","}* params>) <FuncBody body>`) {
  return func([cst2astParam(p) | p <- params], cst2ast(body), inferredT());
}

Func cst2ast((Func) `(<{IdentOrIdentWithType ","}* params>) -\> <Type returnType> = <FuncBody body>`) {
  return func([cst2astParam(p) | p <- params], cst2ast(body), cst2ast(returnType));
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

Statement cst2ast((Statement) `let <LValue lval>: <Type tp>;`) {
  return declStat(lvalueName(lval), cst2ast(tp));
}

Statement cst2ast((Statement) `<LValue lval> = <Exp rval>;`) {
  return smarthome::AST::assignStat(cst2ast(lval), cst2ast(rval));
}

Statement cst2ast((Statement) `let <LValue lval>: <Type tp> = <Exp rval>;`) {
  return declAssignStat(lvalueName(lval), cst2ast(tp), cst2ast(rval));
}

Statement cst2ast((Statement) `let <LValue lval> = <Exp rval>;`) {
  return declAssignStat(lvalueName(lval), inferredT(), cst2ast(rval));
}

Statement cst2ast((Statement) `if <Exp cond> then <Statement* ifpart> else <Statement* elsepart> end`) {
  return ifElseStat(cst2ast(cond), [cst2ast(s) | s <- ifpart], [cst2ast(s) | s <- elsepart]);
}
Statement cst2ast(Statement tree: (Statement) `if <Exp cond> then <Statement* ifpart> end`) {
  return ifElseStat(cst2ast(cond), [cst2ast(s) | s <- ifpart], [], src=tree.src);
}

Statement cst2ast(Statement tree: (Statement) `while <Exp cond> do <Statement* body> end`) {
  return whileStat(cst2ast(cond), [cst2ast(s) | s <- body], src=tree.src);
}

Statement cst2ast((Statement) `continue;`) = smarthome::AST::\continue();

Statement cst2ast((Statement) `break;`) = smarthome::AST::\break();

Statement cst2ast((Statement) `return;`) = smarthome::AST::\return(smarthome::AST::primCon(smarthome::AST::\tuple([])));

Statement cst2ast((Statement) `return <Exp exp>;`) = \return(cst2ast(exp));

Statement cst2ast((Statement) `send(<{Exp ","}* params>);`) {
  return send([cst2ast(p) | p <- params]);
}

LValue cst2ast((LValue) `<Ident id>`) = var(cst2ast(id));

LValue cst2ast((LValue) `<LValue lhs>[<Exp idx>]`) = smarthome::AST::index(cst2ast(lhs), cst2ast(idx));

LValue cst2ast((LValue) `<LValue lhs>.<Ident fieldName>`) = field(cst2ast(lhs), cst2ast(fieldName));

Exp cst2ast((Exp) `(<Exp exp>)`) = cst2ast(exp);

Exp cst2ast((Exp) `<Primitive primitive>`) = smarthome::AST::primCon(cst2ast(primitive));

Exp cst2ast((Exp) `<StateCon stateCon>`) = cst2ast(stateCon);

Exp cst2ast((Exp) `<LValue lval>`) = smarthome::AST::lvalue(cst2ast(lval));

Exp cst2ast((Exp) `not <Exp exp>`) = smarthome::AST::\not(cst2ast(exp));

Exp cst2ast((Exp) `<Exp lhs> * <Exp rhs>`) = smarthome::AST::mul(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> / <Exp rhs>`) = smarthome::AST::div(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> + <Exp rhs>`) = smarthome::AST::add(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> - <Exp rhs>`) = smarthome::AST::sub(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> \> <Exp rhs>`) = smarthome::AST::gt(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> \< <Exp rhs>`) = smarthome::AST::lt(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> \>= <Exp rhs>`) = smarthome::AST::geq(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> \<= <Exp rhs>`) = smarthome::AST::leq(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> == <Exp rhs>`) = smarthome::AST::eq(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast(Exp tree: (Exp) `<Exp lhs> in <Exp rhs>`) = smarthome::AST::\in(cst2ast(lhs), cst2ast(rhs), src=tree.src);

Exp cst2ast((Exp) `<Exp lhs> and <Exp rhs>`) = smarthome::AST::\and(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((Exp) `<Exp lhs> or <Exp rhs>`) = smarthome::AST::\or(cst2ast(lhs), cst2ast(rhs));

Exp cst2ast((StateCon) `<Ident name>(<{Exp ","}* params>)`) {
  return call(cst2ast(name), [cst2ast(p) | p <- params]);
}

Primitive cst2ast((Primitive) `<Natural n>`) = integer(toInt("<n>"));

Primitive cst2ast((Primitive) `<String s>`) = smarthome::AST::string(unquote("<s>"));

Primitive cst2ast((Primitive) `true`) = boolean(true);

Primitive cst2ast((Primitive) `false`) = boolean(false);

Primitive cst2ast((Primitive) `{ <{MapKeyValuePair ","}* pairs> }`) {
  return \map((k: v | <k, v> <- [cst2ast(p) | p <- pairs]));
}

Primitive cst2ast((Primitive) `[ <Primitive* values> ]`) {
  return smarthome::AST::\list([cst2ast(v) | v <- values]);
}

Primitive cst2ast((Primitive) `(<{Primitive ","}* values>)`) {
  return \tuple([cst2ast(v) | v <- values]);
}

tuple[str, Primitive] cst2ast((MapKeyValuePair) `<Primitive key> = <Primitive val>`) {
  return <primitiveKey(cst2ast(key)), cst2ast(val)>;
}

tuple[str, Primitive] cst2ast(MapKeyValuePair tree: (MapKeyValuePair) `<Primitive key> = <Ident enumname> "." <Ident valuename>`) {
  return <primitiveKey(cst2ast(key)), \enum(cst2ast(enumname), cst2ast(valuename), src=tree.src)>;
}


Type cst2ast((Type) `bool`) = booleanT();

Type cst2ast((Type) `str`) = stringT();

Type cst2ast((Type) `map[<Type keyType>, <Type valueType>]`) = \mapT(cst2ast(keyType), cst2ast(valueType));

Type cst2ast((Type) `list[<Type tp>]`) = \listT(cst2ast(tp));

Type cst2ast((Type) `tuple[<{Type ","}* types>]`) = \tupleT([cst2ast(t) | t <- types]);

Type cst2ast((Type) `<Ident id>`) = namedT(cst2ast(id));

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
