module smarthome::AST

data System(loc src=|unknown:///|)
= system(list[Component] components, list[Connection] connections);

alias ComponentID = str;
alias PortName = str;
alias StateName = str;
data PortID(loc src=|unknown:///|)
= portID(ComponentID component, PortName port)
;
data ExternalPort(loc src=|unknown:///|)
= http_json(str uri)
| http_xml(str uri)
;
alias ExternalSourcePort = ExternalPort;
alias ExternalTargetPort = ExternalPort;
data ChannelType(loc src=|unknown:///|)
= http_xml()
| http_json()
;

data Component(loc src=|unknown:///|)
= component(ComponentID id, list[Port] ports, FSM state_machine);

data Connection(loc src=|unknown:///|)
= internal_connection(PortID sourcePort, PortID targetPort)
| external_source_connection(ExternalSourcePort externalSource, PortID targetPort)
| external_target_connection(PortID sourcePort, ExternalTargetPort externalTarget);

data Port(loc src=|unknown:///|)
= port(PortName name, Type dt);

data FSM(loc src=|unknown:///|)
= transition_list(list[Decl] params, Exp initial_state, list[Transition] transitions)
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
| specificMessageFromPort(Primitive d, PortName port)
;

data Option[&T](loc src=|unknown:///|) = some(&T inner) | none();

// https://www.rascal-mpl.org/docs/Recipes/Languages/Pico/Abstract/
data Func(loc src=|unknown:///|)
= func(list[tuple[Type, str]] params, list[Statement], Type return_type);

data Decl(loc src=|unknown:///|) = decl(str varname, Type tp);

data Statement(loc src=|unknown:///|)
= declStat(str varname, Type tp)
| assignStat(LValue lval, Exp rval)
| ifElseStat(Exp cond, list[Statement] ifpart, list[Statement] elsepart)
| whileStat(Exp cond, list[Statement] body)
| \continue()
| \break()
| \return(Exp exp)
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
= inferred_t()
| integer_t()
| boolean_t()
| string_t()
| named_t(str name)
// | schema(map[str, Type] obj)
| \map_t()
| \list_t(Type arr_type)
| \tuple_t(list[Type] tuple_types)
;
