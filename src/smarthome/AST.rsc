module smarthome::AST

data System(loc src=|unknown:///|)
= system(list[Component] components, list[Connection] connections);

alias ComponentID = str;
alias PortName = str;
alias StateName = str;
data PortID
= portID(ComponentID component, PortName port)
;
data ExternalSourcePort
= http(str uri)
;  
data ExternalTargetPort
= http_json(str uri)
| http_xml(str uri)
;
data ChannelType
= http_xml()
| http_json()
;

data Component
= component(ComponentID id, list[Port] ports, FSM state_machine);

data Connection
= internal_connection(PortID source, PortID target, Type dt, ChannelType ct)
| external_source_connection(ExternalSourcePort source, PortID target, Type dt)
| external_target_connection(PortID source, ExternalTargetPort target, Type dt);

data Port
= port(PortName name, Type dt);

data FSM
= transition_list(list[Transition])
;

data State
= state(StateName name, list[tuple[str, Type]] d)
;

// condition should be like 'state => state.value == 0'
// action should be like 'state, callback' => { callback(type, port, payload), return targetState data }
data Transition
= transition(State sourceState, State targetState, Event event, Func condition, Func action)
;

data Event
= anyMessageFromPort(PortName port)
| specificMessageFromPort(Primitive d, PortName port)
;

data Option[&T] = some(&T inner) | none();

// https://www.rascal-mpl.org/docs/Recipes/Languages/Func/AbstractSyntax/
data Func
= func(list[tuple[Type, str]] params, Exp body, Type return_type);

data Exp
= err(str msg)
| let(list[BINDING] bindings, Exp body)
| cond(Exp cond, Exp then, Exp otherwise)
| var(str name)
| prim(Primitive val)
// call(str name, list[Exp] args)

| mul(Exp lhs, Exp rhs)
| div(Exp lhs, Exp rhs)
| add(Exp lhs, Exp rhs)
| sub(Exp lhs, Exp rhs)
| gt(Exp lhs, Exp rhs)
| lt(Exp lhs, Exp rhs)
| geq(Exp lhs, Exp rhs)
| leq(Exp lhs, Exp rhs)

| seq(Exp lhs, Exp rhs)
| assign(Exp lhs, Exp rhs)
;

data BINDING = binding(str var, Exp exp);

data Primitive
= integer(int i)
| string(str s)
| \map(map[str, Primitive] obj)
| \list(list[Primitive] arr)
| \tuple(list[Primitive] tup)
;

data Type
= inferred_t()
| integer_t()
| string_t()
// | schema(map[str, Type] obj)
| \map_t()
| \list_t(Type arr_type)
| \tuple_t(list[Type] tuple_types)
;