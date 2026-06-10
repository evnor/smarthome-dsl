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
= internal_connection(PortID source, PortID target, TYPE dt, ChannelType ct)
| external_source_connection(ExternalSourcePort source, PortID target, TYPE dt)
| external_target_connection(PortID source, ExternalTargetPort target, TYPE dt);

data Port
= port(PortName name, TYPE dt);

data FSM
= transition_list(list[Transition])
;

data State
= state(StateName name, list[tuple[str,TYPE]] d)
;

// condition should be like 'state => state.value == 0'
// action should be like 'state, callback' => { callback(type, port, payload), return targetState data }
data Transition
= transition(State sourceState, State targetState, Event event, FUNCTION condition, FUNCTION action)
;

data Event
= anyMessageFromPort(PortName port)
| specificMessageFromPort(VALUE d, PortName port)
;

data TYPE
= inferred()
| integer()
| string()
| schema(map[str, TYPE] obj)
| object()
| array(TYPE arr_type)
| tup(list[TYPE] tuple_types)
;

data FUNCTION
= function(list[TYPE] params, list[str] param_bindings, EXP body);

data EXP
= val(VALUE v)
| scope(list[EXP] exprs)
| binding(LVALUE lhs, EXP rhs)
;

data LVALUE
= var_name(str name)
| index(LVALUE obj, EXP idx)
;

data VALUE
= integer(int i)
| string(str s)
| schema(map[str, VALUE] obj)
| object(map[str, VALUE] obj)
| array(list[VALUE] arr)
| tup(list[VALUE] tup)
;