module smarthome::AST

data System(loc src=|unknown:///|)
= system(list[Component] components, list[Connection] connections, list[EnumDef] types);

alias ComponentID = str;
alias PortName = str;
alias StateName = str;
data PortID(loc src=|unknown:///|)
= portID(ComponentID component, PortName port)
;
data ExternalPort(loc src=|unknown:///|)
= httpJson(str uri)
| httpXml(str uri)
;
alias ExternalSourcePort = ExternalPort;
alias ExternalTargetPort = ExternalPort;
data ChannelType(loc src=|unknown:///|)
= httpXml()
| httpJson()
;

data Component(loc src=|unknown:///|)
= component(ComponentID id, list[Port] ports, FSM state_machine);

data EnumDef(loc src=|unknown:///|)
= enumDef(str name, Type baseType, list[EnumValueDef] values);

data EnumValueDef(loc src=|unknown:///|)
= enumValueDef(str name, Option[Exp] val);

data Connection(loc src=|unknown:///|)
= internalConnection(PortID sourcePort, PortID targetPort)
| externalSourceConnection(ExternalSourcePort externalSource, PortID targetPort)
| externalTargetConnection(PortID sourcePort, ExternalTargetPort externalTarget)
;

data Port(loc src=|unknown:///|)
= port(PortName name, Type dt);

data FSM(loc src=|unknown:///|)
= transitionList(list[State] states, Exp initialState, list[Transition] transitions)
; //Exp for initial_state?

data State(loc src=|unknown:///|)
= state(StateName name, list[tuple[str, Type]] d)
;

// condition should be like 'state => state.value == 0'
// action should be like 'state, callback' => { callback(type, port, payload), return targetState data }
data Transition(loc src=|unknown:///|)
= transition(State sourceState, State targetState, Event event, Func condition, Func action)
;

data Event(loc src=|unknown:///|)
= anyMessageFromPort(PortName port)
| specificMessageFromPort(Exp d, PortName port)
;

data Option[&T](loc src=|unknown:///|) = some(&T inner) | none();

// https://www.rascal-mpl.org/docs/Recipes/Languages/Pico/Abstract/
data Func(loc src=|unknown:///|)
= func(list[tuple[Type, str]] params, list[Statement] body, Type returnType);

data Decl(loc src=|unknown:///|) = decl(str varname, Type tp);

data Statement(loc src=|unknown:///|)
= declStat(str varname, Type tp)
| declAssignStat(str varname, Type tp, Exp rval)
| assignStat(LValue lval, Exp rval)
| ifElseStat(Exp cond, list[Statement] ifpart, list[Statement] elsepart)
| whileStat(Exp cond, list[Statement] body)
| \continue()
| \break()
| \return(Exp exp)
| send(list[Exp] params)
;

data LValue(loc src=|unknown:///|)
= var(str varname)
| index(LValue lhs, Exp idx)
| field(LValue lhs, str field)
;

data Exp(loc src=|unknown:///|)
= primCon(Primitive val)
| lvalue(LValue lval)
| call(str fname, list[Exp] params)

| mul(Exp lhs, Exp rhs)
| div(Exp lhs, Exp rhs)
| add(Exp lhs, Exp rhs)
| sub(Exp lhs, Exp rhs)
| gt(Exp lhs, Exp rhs)
| lt(Exp lhs, Exp rhs)
| eq(Exp lhs, Exp rhs)
| neq(Exp lhs, Exp rhs)
| geq(Exp lhs, Exp rhs)
| leq(Exp lhs, Exp rhs)
| \and(Exp lhs, Exp rhs)
| \or(Exp lhs, Exp rhs)
| \not(Exp exp)
;

data Primitive(loc src=|unknown:///|)
= integer(int i)
| string(str s)
| boolean(bool b)
| \map(map[str, Primitive] obj)
| \list(list[Primitive] arr)
| \tuple(list[Primitive] tup)
;

data Type(loc src=|unknown:///|)
= inferredT()
| integerT()
| booleanT()
| stringT()
| namedT(str name)
| \mapT(Type keyType, Type valueType)
| \listT(Type arrType)
| \tupleT(list[Type] tupleTypes)
;
