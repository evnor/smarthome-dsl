module smarthome::Generator

import IO;
import vis::Text;
import List;
import Map;

import smarthome::AST;
import smarthome::Parser;
import smarthome::CST2AST;
import smarthome::Checker;

public str generatePythonFile(loc input, loc output) {
  System sys = cst2ast(parseSmrt(input));
  list[CheckError] errors = check(sys);
  if (errors != []) {
    println(joinLines(["<e>" | e <- errors]));
    throw "Cannot generate Python for invalid Smarthome DSL program";
  }
  // println(prettyNode(sys));
  str code = generatePython(sys);
  writeFile(output, code);
  return code;
}

public str generatePython(System sys) {
  list[str] lines = [
    "from http.server import BaseHTTPRequestHandler, HTTPServer",
    "from dataclasses import dataclass",
    "from abc import ABC, abstractmethod",
    "from enum import IntEnum",
    "from typing import Generic, TypeVar",
    "import requests",
    "import json",
    "",
    "hostName = \"localhost\"",
    "serverPort = 8080",
    ""
  ];

  for (EnumDef enumDef <- sys.types) {
    lines += generateEnum(enumDef);
  }

  lines += [
    "",
    "T = TypeVar(\"T\")",
    "class Port(Generic[T], ABC):",
    "    component: str",
    "    name: str",
    "    data: T",
    "    @abstractmethod",
    "    def send(self): ...",
    ""
  ];

  for (Component c <- sys.components) {
    lines += generatePorts(c, sys.connections);
  }

  lines += [
    "",
    "class State(ABC):",
    "    @abstractmethod",
    "    def step(self, event) -\> \"State\": ...",
    ""
  ];

  for (Component c <- sys.components) {
    lines += generateStates(c, sys.connections);
  }

  lines += generateRuntime(sys.components, sys.connections);

  return joinLines(lines);
}

list[str] generateEnum(EnumDef enumDefinition) {
  str name = "";
  list[EnumValueDef] values = [];
  switch (enumDefinition) {
    case enumDef(enumName, _, enumValues): {
      name = enumName;
      values = enumValues;
    }
  }

  list[str] lines = ["class <name>(IntEnum):"];
  int nextValue = 0;

  if (values == []) {
    lines += ["    pass"];
    return lines;
  }

  for (EnumValueDef enumValue <- values) {
    switch (enumValue) {
      case enumValueDef(valueName, enumValueOption): {
        switch (enumValueOption) {
          case some(primCon(integer(i))): {
            lines += ["    <valueName> = <i>"];
            nextValue = i + 1;
          }
          default: {
            lines += ["    <valueName> = <nextValue>"];
            nextValue += 1;
          }
        }
      }
    }
  }

  return lines;
}

list[str] generatePorts(Component componentDef, list[Connection] connections) {
  str componentId = "";
  list[Port] ports = [];
  switch (componentDef) {
    case component(id, componentPorts, _): {
      componentId = id;
      ports = componentPorts;
    }
  }

  list[str] lines = [];

  for (Port p <- ports) {
    switch (p) {
      case port(portName, tp): {
        str cls = portClass(componentId, portName);
        str pyType = typeName(tp);
        str targetUri = externalTargetUri(componentId, portName, connections);
        list[tuple[str,str]] internalTargets = [<tgtComp, tgtPort> 
          | internalConnection(portID(srcComp, srcPort), portID(tgtComp, tgtPort)) <- connections, 
          srcPort == portName && srcComp == componentId];

        lines += [
          "class <cls>(Port[<pyType>]):",
          "    component = \"<componentId>\"",
          "    name = \"<portName>\"",
          "    data: <pyType>",
          "    def __init__(self, data: <pyType>):",
          "        self.data = data"
        ];

        if (targetUri != "") {
          lines += [
            "    def to_json(self):",
            "        return json.dumps({\"IntEnumValue\": int(self.data)})",
            "    def send(self):",
            "        requests.post(",
            "            \"http://localhost:8081<targetUri>\",",
            "            data=self.to_json(),",
            "            headers={\"Content-Type\": \"application/json\"},",
            "        )"
          ];
        }
        else {
          lines += ["    def send(self):"];
          if (internalTargets == []) {
            lines += ["        ..."];
          }
        }
        for (<comp, port> <- internalTargets) {
          lines += ["        event_queue.append(<portClass(comp, port)>(self.data))"];
        }
      }
    }
  }

  return lines;
}

list[str] generateStates(Component componentDef, list[Connection] connections) {
  str componentId = "";
  list[Port] ports = [];
  list[State] states = [];
  list[Transition] transitions = [];
  switch (componentDef) {
    case component(id, componentPorts, transitionList(componentStates, _, componentTransitions)): {
      componentId = id;
      ports = componentPorts;
      states = componentStates;
      transitions = componentTransitions;
    }
  }

  list[str] lines = [];

  for (State s <- states) {
    switch (s) {
      case state(stateName, fields): {
        lines += [
          "@dataclass",
          "class <stateClass(componentId, stateName)>(State):"
        ];

        if (fields != []) {
          for (<fieldName, tp> <- fields) {
            lines += ["    <fieldName>: <typeName(tp)>"];
          }
          lines += [""];
        }

        lines += [
          "    def step(self, event):"
        ];

        for (Transition t <- transitions) {
          switch (t) {
            case transition(state(sourceName, _), _, event, condition, action): {
              if (sourceName == stateName) {
                lines += generateTransition(componentId, ports, event, condition, action);
              }
            }
          }
        }

        lines += ["        return self", ""];
      }
    }
  }

  return lines;
}

list[str] generateTransition(str componentId, list[Port] ports, Event event, Func condition, Func action) {
  str eventCheck = eventPredicate(componentId, event);
  str conditionCheck = conditionPredicate(componentId, condition);
  list[Statement] actionBody = [];
  list[tuple[Type, str]] actionParams = [];
  switch (action) {
    case func(params, body, _): {
      actionBody = body;
      actionParams = params;
    }
  }
  list[str] lines = [
    "        if <eventCheck>:",
    "            if <conditionCheck>:"
  ];

  if (size(actionParams) >= 2) {
    lines += indent(["<actionParams[1][1]> = event.data"], 16);
  }

  lines += indent(generateStatements(componentId, actionBody), 16);
  return lines;
}

list[str] generateRuntime(list[Component] components, list[Connection] connections) {
  list[str] lines = [
    "event_queue: list[Port] = []",
    "cur_state: dict[str, State] = {"
  ];
  bool first = true;
  for (component(id, _, transitionList(_, componentInitialState, _)) <- components) {
    if (!first) {
      lines[size(lines)-1] += ",";
    }
    lines += ["    \"<id>\": <generateExp(id, componentInitialState)>"];
    first = false;
  }
  lines += [
    "}",
    "def handle_event(event: Port):",
    "    global cur_state",
    "    event_queue.append(event)",
    "    while len(event_queue) \> 0:",
    "        event = event_queue.pop(0)",
    "        for component, state in cur_state.items():",
    "            cur_state[component] = state.step(event)",
    "",
    "",
    "class Server(BaseHTTPRequestHandler):",
    "    def do_POST(self):"
  ];

  first = true;
  for (component(componentId, ports, _) <- components) {
    list[Connection] incoming = incomingConnections(componentId, connections);
    for (Connection c <- incoming) {
      switch (c) {
        case externalSourceConnection(httpJson(uri), portID(_, portName)): {
          Type portType = findPortType(portName, ports);
          str prefix = "elif";
          if (first) {
            prefix = "if";
          }
          lines += [
            "        <prefix> self.path == \"<uri>\":",
            "            content_length = int(self.headers.get(\"Content-Length\", 0))",
            "            body = self.rfile.read(content_length)",
            "            data = json.loads(body)"
          ];
          lines += indent(generateDataMarshallExpr(portType, portName), 12);
          lines += [
            "            event = <portClass(componentId, portName)>(data)",
            "            handle_event(event)",
            "            self.send_response(200)",
            "            self.send_header(\"Content-Type\", \"text/plain\")",
            "            self.end_headers()",
            "            self.wfile.write(cur_state.__repr__().encode())"
          ];
          first = false;
        }
      }
    }
  }
  if (!first) {
    lines += "        else:";
  }
  lines += [
    "            self.send_response(404)",
    "            self.end_headers()"
  ];

  lines += [
    "",
    "",
    "if __name__ == \"__main__\":",
    "    webServer = HTTPServer((hostName, serverPort), Server)",
    "    print(\"Server started http://%s:%s\" % (hostName, serverPort))",
    "    try:",
    "        webServer.serve_forever()",
    "    except KeyboardInterrupt:",
    "        pass",
    "    webServer.server_close()",
    "    print(\"Server stopped.\")"
  ];

  return lines;
}

list[str] generateStatements(str componentId, list[Statement] statements) {
  list[str] lines = [];

  for (Statement statement <- statements) {
    switch (statement) {
      case declStat(name, _):
        lines += ["<name> = None"];
      case declAssignStat(name, _, rval):
        lines += ["<name> = <generateExp(componentId, rval)>"];
      case assignStat(lval, rval):
        lines += ["<generateLValue(componentId, lval)> = <generateExp(componentId, rval)>"];
      case ifElseStat(cond, ifpart, elsepart): {
        lines += ["if <generateExp(componentId, cond)>:"];
        lines += indent(generateStatements(componentId, ifpart), 4);
        lines += ["else:"];
        lines += indent(generateStatements(componentId, elsepart), 4);
      }
      case whileStat(cond, body): {
        lines += ["while <generateExp(componentId, cond)>:"];
        lines += indent(generateStatements(componentId, body), 4);
      }
      case \continue():
        lines += ["continue"];
      case \break():
        lines += ["break"];
      case \return(exp):
        lines += ["return <generateExp(componentId, exp)>"];
      case send(params): {
        if (size(params) == 2) {
          switch (params[0]) {
            case lvalue(var(portName)):
              lines += ["<portClass(componentId, portName)>(<generateExp(componentId, params[1])>).send()"];
            default:
              lines += ["# unsupported send target"];
          }
        }
      }
    }
  }

  if (lines == []) {
    return ["pass"];
  }

  return lines;
}

str generateExp(str componentId, Exp exp) {
  switch (exp) {
    case primCon(p):
      return generatePrimitive(p);
    case lvalue(lval):
      return generateLValue(componentId, lval);
    case call(name, params): {
      str args = generateExpList(componentId, params);
      if (name == "min" || name == "max") {
        return "<name>(<args>)";
      }
      return "<stateClass(componentId, name)>(<args>)";
    }
    case mul(lhs, rhs):
      return "(<generateExp(componentId, lhs)> * <generateExp(componentId, rhs)>)";
    case div(lhs, rhs):
      return "(<generateExp(componentId, lhs)> / <generateExp(componentId, rhs)>)";
    case add(lhs, rhs):
      return "(<generateExp(componentId, lhs)> + <generateExp(componentId, rhs)>)";
    case sub(lhs, rhs):
      return "(<generateExp(componentId, lhs)> - <generateExp(componentId, rhs)>)";
    case gt(lhs, rhs):
      return "(<generateExp(componentId, lhs)> \> <generateExp(componentId, rhs)>)";
    case lt(lhs, rhs):
      return "(<generateExp(componentId, lhs)> \< <generateExp(componentId, rhs)>)";
    case eq(lhs, rhs):
      return "(<generateExp(componentId, lhs)> == <generateExp(componentId, rhs)>)";
    case neq(lhs, rhs):
      return "(<generateExp(componentId, lhs)> != <generateExp(componentId, rhs)>)";
    case geq(lhs, rhs):
      return "(<generateExp(componentId, lhs)> \>= <generateExp(componentId, rhs)>)";
    case leq(lhs, rhs):
      return "(<generateExp(componentId, lhs)> \<= <generateExp(componentId, rhs)>)";
    case \in(lhs, rhs):
      return "(<generateExp(componentId, lhs)> in <generateExp(componentId, rhs)>)";
    case \and(lhs, rhs):
      return "(<generateExp(componentId, lhs)> and <generateExp(componentId, rhs)>)";
    case \or(lhs, rhs):
      return "(<generateExp(componentId, lhs)> or <generateExp(componentId, rhs)>)";
    case \not(inner):
      return "(not <generateExp(componentId, inner)>)";
  }

  return "None";
}

str generateLValue(str componentId, LValue lval) {
  switch (lval) {
    case var(name):
      return name;
    case field(var(owner), fieldName): {
      if (owner == "state") {
        return "self.<fieldName>";
      }
      return "<owner>.<fieldName>";
    }
    case field(lhs, fieldName):
      return "<generateLValue(componentId, lhs)>.<fieldName>";
    case index(lhs, idx):
      return "<generateLValue(componentId, lhs)>[<generateExp(componentId, idx)>]";
  }

  return "";
}

str generatePrimitive(Primitive primitive) {
  switch (primitive) {
    case integer(i):
      return "<i>";
    case string(s):
      return "\"<s>\"";
    case boolean(b): {
      if (b) {
        return "True";
      }
      return "False";
    }
    case \list(values):
      return "[<generatePrimitiveList(values)>]";
    case \tuple(values):
      return "(<generatePrimitiveList(values)>)";
    case \map(values):
      return "{<generatePrimitiveMap(values)>}";
    case \enum(enumName,fieldName):
      return "(<enumName>.<fieldName>)";
  }

  return "None";
}

str eventPredicate(str componentId, Event event) {
  switch (event) {
    case anyMessageFromPort(portName):
      return "isinstance(event, <portClass(componentId, portName)>)";
    case specificMessageFromPort(payload, portName):
      return "isinstance(event, <portClass(componentId, portName)>) and event.data == <generateExp(componentId, payload)>";
  }
  return "False";
}

str conditionPredicate(str componentId, Func f) {
  switch (f) {
    case func(_, [\return(exp)], _):
      return generateExp(componentId, exp);
    default:
      return "True";
  }
}

str externalTargetUri(str componentId, str portName, list[Connection] connections) {
  for (Connection conn <- connections) {
    switch (conn) {
      case externalTargetConnection(portID(c, p), httpJson(uri)): {
        if (c == componentId && p == portName) {
          return uri;
        }
      }
    }
  }
  return "";
}

list[Connection] incomingConnections(str componentId, list[Connection] connections) {
  list[Connection] result = [];
  for (Connection c <- connections) {
    switch (c) {
      case externalSourceConnection(_, portID(targetComponent, _)): {
        if (targetComponent == componentId) {
          result += [c];
        }
      }
    }
  }
  return result;
}

Type findPortType(str portName, list[Port] ports) {
  for (Port p <- ports) {
    switch (p) {
      case port(name, tp): {
        if (name == portName) {
          return tp;
        }
      }
    }
  }
  return inferredT();
}

str portClass(str componentId, str portName) = "<componentId><portName>";

str stateClass(str componentId, str name) = "State<componentId><name>";

str typeName(Type tp) {
  switch (tp) {
    case integerT():
      return "int";
    case booleanT():
      return "bool";
    case stringT():
      return "str";
    case namedT(name):
      return name;
    case \listT(elem):
      return "list[<typeName(elem)>]";
    case \mapT(key, val):
      return "dict[<typeName(key)>, <typeName(val)>]";
    case \tupleT(elems):
      return "tuple[<typeNameList(elems)>]";
    default:
      return "object";
  }
}

list[str] indent(list[str] lines, int spaces) {
  str prefix = repeatSpace(spaces);
  list[str] result = [];
  for (str line <- lines) {
    result += ["<prefix><line>"];
  }
  return result;
}

str generateExpList(str componentId, list[Exp] values) {
  list[str] generated = [];
  for (Exp e <- values) {
    generated += [generateExp(componentId, e)];
  }
  return joinComma(generated);
}

str generatePrimitiveList(list[Primitive] values) {
  list[str] generated = [];
  for (Primitive p <- values) {
    generated += [generatePrimitive(p)];
  }
  return joinComma(generated);
}

str generatePrimitiveMap(map[str, Primitive] values) {
  list[str] generated = [];
  for (<key, val> <- toList(values)) {
    generated += ["\"<key>\":<generatePrimitive(val)>"];
  }
  return joinComma(generated);
}

list[str] generateDataMarshallExpr(Type tp, str portName) {
  switch (tp) {
    case inferredT(): {
      throw "This should be unreachable. Port <portName> has type inferredT";
    }
    case namedT(name): return ["data = <generateMarshallingExpr("data", tp, 0)>"];
    case \mapT(keyType, valueType): return ["data = <generateMarshallingExpr("data", tp, 0)>"];
    case \listT(arrType): return ["data = <generateMarshallingExpr("data", tp, 0)>"];
    case \tupleT(tupleTypes): return ["data = <generateMarshallingExpr("data", tp, 0)>"];
    default: return [];
  }
}

str generateMarshallingExpr(str accessor, Type tp, int depth) {
  switch (tp) {
      case namedT(name): return "<name>(<accessor>)";
      case \mapT(keyType, valueType): return "{<generateMarshallingExpr("k<depth>", keyType, depth+1)>: <generateMarshallingExpr("v<depth>", valueType, depth+1)> for k<depth>, v<depth> in <accessor>.items()}";
      case \listT(arrType): return "[<generateMarshallingExpr("el<depth>", arrType, depth+1)> for el<depth> in <accessor>]";
      case \tupleT(tupleTypes): return generateTupleMarshallExpr(accessor, tupleTypes, depth+1);
      case integerT(): return "int(<accessor>)"; // These could be just "<accessor>", but this way we catch unexpected values
      case booleanT(): return "bool(<accessor>)";
      case stringT(): return "str(<accessor>)";
      default: throw "Unimplemented";
  }
}

str generateTupleMarshallExpr(str accessor, list[Type] types, int depth) {
  list[str] exprs = [generateMarshallingExpr("<accessor>[<i>]", types[i], depth) | i <- [0..size(types)]];
  if (size(exprs) == 0) {
    return "tuple()";
  }
  return "(<joinComma(exprs)>,)";
}

str typeNameList(list[Type] values) {
  list[str] generated = [];
  for (Type t <- values) {
    generated += [typeName(t)];
  }
  return joinComma(generated);
}

str repeatSpace(int count) {
  str result = "";
  int i = 0;
  while (i < count) {
    result += " ";
    i += 1;
  }
  return result;
}

str joinComma(list[str] values) {
  return joinStrings(values, ", ");
}

str joinLines(list[str] values) {
  return joinStrings(values, "\n");
}

str joinStrings(list[str] values, str separator) {
  str result = "";
  bool first = true;
  for (str item <- values) {
    if (!first) {
      result += separator;
    }
    result += item;
    first = false;
  }
  return result;
}
