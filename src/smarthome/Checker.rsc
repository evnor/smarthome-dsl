module smarthome::Checker

import List;

import smarthome::AST;

data CheckError
  = duplicateComponent(str component)
  | duplicatePort(str component, str port)
  | duplicateType(str name)
  | duplicateEnumValue(str enumName, str valueName)
  | duplicateState(str component, str stateName)
  | unknownComponent(str component)
  | unknownPort(str component, str port)
  | unknownType(str name)
  | unknownEnumValue(str enumName, str valueName)
  | unknownState(str component, str stateName)
  | unknownVariable(str name)
  | unknownField(Type owner, str field)
  | unknownFunction(str name)
  | cannotInferConnectionType(Connection connection)
  | cannotInferChannelType(Connection connection)
  | typeMismatch(Type expected, Type actual)
  | invalidOperand(str operator, Type actual, str msg)
  | invalidCondition(Type actual)
  | invalidReturn(Type expected, Type actual)
  | invalidSend(str reason)
  | wrongArity(str name, int expectedArity, int actualArity)
  ;

data CheckedConnection
= checked_internal_connection(PortID sourcePort, PortID targetPort, Type dt, ChannelType ct)
| checked_external_source_connection(ExternalSourcePort externalSource, PortID targetPort, Type dt, ChannelType ct)
| checked_external_target_connection(PortID sourcePort, ExternalTargetPort externalTarget, Type dt, ChannelType ct);

alias PortTable = map[tuple[str component, str port], Type];
alias ComponentTable = map[str, Component];
alias TypeTable = map[str, EnumDef];
alias StateTable = map[str, State];
alias VarTable = map[str, Type];

PortTable collectPorts(System sys) {
  PortTable table = ();

  for (component(id, ports, _) <- sys.components) {
    for (port(name, tp) <- ports) {
      table += (<id, name>: tp);
    }
  }

  return table;
}

ComponentTable collectComponents(System sys) {
  ComponentTable table = ();
  for (Component c <- sys.components) {
    switch (c) {
      case component(id, _, _):
        table += (id: c);
    }
  }
  return table;
}

TypeTable collectTypes(System sys) {
  TypeTable table = ();
  for (EnumDef t <- sys.types) {
    switch (t) {
      case enumDef(name, _, _):
        table += (name: t);
    }
  }
  return table;
}

list[CheckError] check(System sys) {
  ComponentTable components = collectComponents(sys);
  PortTable ports = collectPorts(sys);
  TypeTable types = collectTypes(sys);
  list[CheckError] errors = [];

  errors += checkDuplicates(sys);
  errors += checkTypeDefinitions(sys, types);

  rewriteEnumCon(sys, types);

  for (component(id, componentPorts, fsm) <- sys.components) {
    for (port(_, tp) <- componentPorts) {
      errors += checkType(tp, types);
    }
    errors += checkFSM(id, componentPorts, fsm, types);
  }

  for (conn <- sys.connections) {
    errors += checkConnection(conn, components, ports);
  }

  return errors;
}

list[CheckError] checkDuplicates(System sys) {
  list[CheckError] errors = [];
  list[str] componentNames = [];
  list[str] typeNames = [];

  for (component(id, ports, transitionList(states, _, _)) <- sys.components) {
    if (id in componentNames) {
      errors += [duplicateComponent(id)];
    }
    componentNames += [id];

    list[str] portNames = [];
    for (port(name, _) <- ports) {
      if (name in portNames) {
        errors += [duplicatePort(id, name)];
      }
      portNames += [name];
    }

    list[str] stateNames = [];
    for (state(name, _) <- states) {
      if (name in stateNames) {
        errors += [duplicateState(id, name)];
      }
      stateNames += [name];
    }
  }

  for (enumDef(name, _, values) <- sys.types) {
    if (name in typeNames) {
      errors += [duplicateType(name)];
    }
    typeNames += [name];

    list[str] valueNames = [];
    for (enumValueDef(valueName, _) <- values) {
      if (valueName in valueNames) {
        errors += [duplicateEnumValue(name, valueName)];
      }
      valueNames += [valueName];
    }
  }

  return errors;
}

void rewriteEnumCon(System sys, TypeTable types) {
  bottom-up visit (sys) {
    case lvalue(field(var(varname), fieldname)): {
      if (varname in types) {
        EnumDef enumdef = types[varname];
        for (enumValueDef(name, _) <- enumdef.values) {
          if (name == fieldname) {
            // println("Rewriting <varname>.<fieldname> as enum");
            insert primCon(\enum(varname, fieldname));
          }
        }
      }
    }
  };
}

list[CheckError] checkTypeDefinitions(System sys, TypeTable types) {
  list[CheckError] errors = [];

  for (enumDef(name, baseType, values) <- sys.types) {
    errors += checkType(baseType, types);

    for (enumValueDef(_, some(exp)) <- values) {
      tuple[Type, list[CheckError]] inferred = inferExp(exp, (), types, ());
      errors += inferred[1];
      if (!compatible(baseType, inferred[0])) {
        errors += [typeMismatch(baseType, inferred[0])];
      }
    }
  }

  return errors;
}

list[CheckError] checkType(Type tp, TypeTable types) {
  switch (tp) {
    case inferredT():
      return [];
    case integerT():
      return [];
    case booleanT():
      return [];
    case stringT():
      return [];
    case namedT(name): {
      if (name in types) {
        return [];
      }
      return [unknownType(name)];
    }
    case \mapT(keyType, valueType):
      return checkType(keyType, types) + checkType(valueType, types);
    case \listT(elemType):
      return checkType(elemType, types);
    case \tupleT(elems):
      return concat([checkType(e, types) | e <- elems]);
  }

  return [];
}

list[CheckError] checkType(Type tp, TypeTable types, StateTable states) {
  switch (tp) {
    case namedT(name): {
      if (name in types || name in states) {
        return [];
      }
      return [unknownType(name)];
    }
    case \mapT(keyType, valueType):
      return checkType(keyType, types, states) + checkType(valueType, types, states);
    case \listT(elemType):
      return checkType(elemType, types, states);
    case \tupleT(elems):
      return concat([checkType(e, types, states) | e <- elems]);
    default:
      return checkType(tp, types);
  }
}

list[CheckError] checkConnection(Connection conn, ComponentTable components, PortTable ports) {
  switch (conn) {
    case internalConnection(portID(srcComp, srcPort), portID(dstComp, dstPort)): {
      list[CheckError] errors = checkPortRef(srcComp, srcPort, components, ports)
                              + checkPortRef(dstComp, dstPort, components, ports);

      if (errors != []) {
        return errors;
      }

      if (!compatible(ports[<srcComp, srcPort>], ports[<dstComp, dstPort>])) {
        return [cannotInferConnectionType(conn)];
      }

      return [];
    }

    case externalSourceConnection(_, portID(dstComp, dstPort)):
      return checkPortRef(dstComp, dstPort, components, ports);

    case externalTargetConnection(portID(srcComp, srcPort), _):
      return checkPortRef(srcComp, srcPort, components, ports);
  }

  return [];
}

list[CheckError] checkPortRef(str component, str portName, ComponentTable components, PortTable ports) {
  if (component notin components) {
    return [unknownComponent(component)];
  }
  if (<component, portName> notin ports) {
    return [unknownPort(component, portName)];
  }
  return [];
}

list[CheckError] checkFSM(str componentName, list[Port] ports, FSM fsm, TypeTable types) {
  switch (fsm) {
    case transitionList(states, initialState, transitions): {
      StateTable stateTable = ();
      for (State s <- states) {
        switch (s) {
          case state(name, _):
            stateTable += (name: s);
        }
      }

      VarTable portTypes = ();
      for (port(name, tp) <- ports) {
        portTypes += (name: tp);
      }
      list[CheckError] errors = [];

      for (state(_, fields) <- states) {
        for (<_, tp> <- fields) {
          errors += checkType(tp, types);
        }
      }

      errors += checkStateConstructor(componentName, initialState, stateTable, types, ());

      for (transition(state(sourceName, _), state(targetName, _), event, condition, action) <- transitions) {
        if (sourceName notin stateTable) {
          errors += [unknownState(componentName, sourceName)];
        }
        if (targetName notin stateTable) {
          errors += [unknownState(componentName, targetName)];
        }

        <portName, errs> = checkEvent(event, portTypes, types, stateTable);
        errors += errs;
        errors += checkFunc(condition, booleanT(), funcCondition(sourceName), portTypes, types, stateTable);
        errors += checkFunc(action, namedT(targetName), funcAction(sourceName, portName), portTypes, types, stateTable);
      }

      return errors;
    }
  }

  return [];
}

tuple[str, list[CheckError]] checkEvent(Event event, VarTable portTypes, TypeTable types, StateTable states) {
  switch (event) {
    case anyMessageFromPort(portName): {
      if (portName in portTypes) {
        return <portName, []>;
      }
      return <portName, [unknownPort("", portName)]>;
    }

    case specificMessageFromPort(payload, portName): {
      if (portName notin portTypes) {
        return <portName, [unknownPort("", portName)]>;
      }

      tuple[Type, list[CheckError]] inferred = inferExp(payload, (), types, states);
      list[CheckError] errors = inferred[1];
      if (!compatible(portTypes[portName], inferred[0])) {
        errors += [typeMismatch(portTypes[portName], inferred[0])];
      }
      return <portName, errors>;
    }
  }

  return <"", []>;
}

data FuncType
= funcCondition(str sourceState)
| funcAction(str sourceState, str portName)
| funcOther()
;

list[CheckError] checkFunc(Func function, Type expectedReturn, FuncType funcType, VarTable portTypes, TypeTable types, StateTable states) {
  switch (function) {
    case func(params, body, declaredReturn): {
      VarTable env = ();
      list[CheckError] errors = [];

      int i = 0;
      for (<tp, name> <- params) {
        Type paramType = tp;
        Option[Type] expected = none();
        switch (funcType) {
          case funcCondition(sourceState): {
            if (i == 0) {
              expected = some(namedT(sourceState));
            } else {
              errors += [wrongArity("condition on <sourceState>", 1, size(params))];
            }
          }
          case funcAction(sourceState, portName): {
            if (i == 0) {
              expected = some(namedT(sourceState));
            } else if (i == 1) {
              expected = some(portTypes[portName]);
            } else {
              errors += [wrongArity("action on <sourceState>", 2, size(params))];
            }
          }
        }
        switch (expected) {
          case some(expect): {
            if (paramType == inferredT()) {
              paramType = expect;
            } else {
              if (!compatible(expect, paramType)) {
                errors += [typeMismatch(expect, paramType)];
              }
            }
          }
        }
        env += (name: paramType);
        errors += checkType(paramType, types, states);
        i += 1;
      }

      Type returnType = declaredReturn;
      if (declaredReturn == inferredT()) {
        returnType = expectedReturn;
      }
      errors += checkType(returnType, types, states);

      tuple[VarTable, list[CheckError], list[Type]] result = checkStatements(body, env, returnType, portTypes, types, states);
      errors += result[1];

      for (actual <- result[2]) {
        if (!compatible(returnType, actual)) {
          errors += [invalidReturn(returnType, actual)];
        }
      }

      if (!compatible(expectedReturn, returnType)) {
        errors += [invalidReturn(expectedReturn, returnType)];
      }

      return errors;
    }
  }

  return [];
}

tuple[VarTable, list[CheckError], list[Type]] checkStatements(list[Statement] statements, VarTable env, Type returnType, VarTable portTypes, TypeTable types, StateTable states) {
  list[CheckError] errors = [];
  list[Type] returns = [];
  VarTable current = env;

  for (statement <- statements) {
    tuple[VarTable, list[CheckError], list[Type]] checked = checkStatement(statement, current, returnType, portTypes, types, states);
    current = checked[0];
    errors += checked[1];
    returns += checked[2];
  }

  return <current, errors, returns>;
}

tuple[VarTable, list[CheckError], list[Type]] checkStatement(Statement statement, VarTable env, Type returnType, VarTable portTypes, TypeTable types, StateTable states) {
  switch (statement) {
    case declStat(name, tp): {
      return <env + (name: tp), checkType(tp, types), []>;
    }

    case declAssignStat(name, tp, rval): {
      tuple[Type, list[CheckError]] inferred = inferExp(rval, env, types, states);
      Type declared = tp;
      if (tp == inferredT()) {
        declared = inferred[0];
      }
      list[CheckError] errors = checkType(declared, types) + inferred[1];
      if (!compatible(declared, inferred[0])) {
        errors += [typeMismatch(declared, inferred[0])];
      }
      return <env + (name: declared), errors, []>;
    }

    case assignStat(lval, rval): {
      tuple[Type, list[CheckError]] lhs = inferLValue(lval, env, types, states);
      tuple[Type, list[CheckError]] rhs = inferExp(rval, env, types, states);
      list[CheckError] errors = lhs[1] + rhs[1];
      if (!compatible(lhs[0], rhs[0])) {
        errors += [typeMismatch(lhs[0], rhs[0])];
      }
      return <env, errors, []>;
    }

    case ifElseStat(cond, ifpart, elsepart): {
      tuple[Type, list[CheckError]] condition = inferExp(cond, env, types, states);
      list[CheckError] errors = condition[1];
      if (!compatible(booleanT(), condition[0])) {
        errors += [invalidCondition(condition[0])];
      }

      tuple[VarTable, list[CheckError], list[Type]] ifChecked = checkStatements(ifpart, env, returnType, portTypes, types, states);
      tuple[VarTable, list[CheckError], list[Type]] elseChecked = checkStatements(elsepart, env, returnType, portTypes, types, states);
      return <env, errors + ifChecked[1] + elseChecked[1], ifChecked[2] + elseChecked[2]>;
    }

    case whileStat(cond, body): {
      tuple[Type, list[CheckError]] condition = inferExp(cond, env, types, states);
      tuple[VarTable, list[CheckError], list[Type]] checkedBody = checkStatements(body, env, returnType, portTypes, types, states);
      list[CheckError] errors = condition[1] + checkedBody[1];
      if (!compatible(booleanT(), condition[0])) {
        errors += [invalidCondition(condition[0])];
      }
      return <env, errors, checkedBody[2]>;
    }

    case \continue():
      return <env, [], []>;

    case \break():
      return <env, [], []>;

    case \return(exp): {
      tuple[Type, list[CheckError]] inferred = inferExp(exp, env, types, states);
      return <env, inferred[1], [inferred[0]]>;
    }

    case send(params):
      return <env, checkSend(params, env, portTypes, types, states), []>;
  }

  return <env, [], []>;
}

list[CheckError] checkSend(list[Exp] params, VarTable env, VarTable portTypes, TypeTable types, StateTable states) {
  if (size(params) != 2) {
    return [wrongArity("send", 2, size(params))];
  }

  switch (params[0]) {
    case lvalue(var(portName)): {
      if (portName notin portTypes) {
        return [unknownPort("", portName)];
      }

      tuple[Type, list[CheckError]] payload = inferExp(params[1], env, types, states);
      list[CheckError] errors = payload[1];
      if (!compatible(portTypes[portName], payload[0])) {
        errors += [typeMismatch(portTypes[portName], payload[0])];
      }
      return errors;
    }
    default:
      return [invalidSend("first argument must be a port name")];
  }
}

list[CheckError] checkStateConstructor(str componentName, Exp exp, StateTable states, TypeTable types, VarTable env) {
  tuple[Type, list[CheckError]] inferred = inferExp(exp, env, types, states);
  return inferred[1];
}

tuple[Type, list[CheckError]] inferExp(Exp exp, VarTable env, TypeTable types, StateTable states) {
  switch (exp) {
    case primCon(primitive):
      return inferPrimitive(primitive);

    case lvalue(lval):
      return inferLValue(lval, env, types, states);

    case call(name, params):
      return inferCall(name, params, env, types, states);

    case add(lhs, rhs):
      return inferNumericBinary("+", lhs, rhs, env, types, states);
    case sub(lhs, rhs):
      return inferNumericBinary("-", lhs, rhs, env, types, states);
    case mul(lhs, rhs):
      return inferNumericBinary("*", lhs, rhs, env, types, states);
    case div(lhs, rhs):
      return inferNumericBinary("/", lhs, rhs, env, types, states);

    case gt(lhs, rhs):
      return inferComparison("\>", lhs, rhs, env, types, states);
    case lt(lhs, rhs):
      return inferComparison("\<", lhs, rhs, env, types, states);
    case geq(lhs, rhs):
      return inferComparison("\>=", lhs, rhs, env, types, states);
    case leq(lhs, rhs):
      return inferComparison("\<=", lhs, rhs, env, types, states);

    case eq(lhs, rhs):
      return inferEquality("==", lhs, rhs, env, types, states);
    case neq(lhs, rhs):
      return inferEquality("!=", lhs, rhs, env, types, states);

    case \in(lhs, rhs):
      return inferIsIn("in", lhs, rhs, env, types, states);

    case \and(lhs, rhs):
      return inferBooleanBinary("and", lhs, rhs, env, types, states);
    case \or(lhs, rhs):
      return inferBooleanBinary("or", lhs, rhs, env, types, states);

    case \not(inner): {
      tuple[Type, list[CheckError]] inferred = inferExp(inner, env, types, states);
      list[CheckError] errors = inferred[1];
      if (!compatible(booleanT(), inferred[0])) {
        errors += [invalidOperand("not", inferred[0], "<inner>")];
      }
      return <booleanT(), errors>;
    }
  }

  return <inferredT(), []>;
}

tuple[Type, list[CheckError]] inferPrimitive(Primitive primitive) {
  switch (primitive) {
    case integer(_):
      return <integerT(), []>;
    case string(_):
      return <stringT(), []>;
    case boolean(_):
      return <booleanT(), []>;
    case \tuple(values): {
      list[Type] types = [];
      list[CheckError] errors = [];
      for (v <- values) {
        tuple[Type, list[CheckError]] inferred = inferPrimitive(v);
        types += [inferred[0]];
        errors += inferred[1];
      }
      return <\tupleT(types), errors>;
    }
    case \list(values): {
      if (values == []) {
        return <\listT(inferredT()), []>;
      }

      tuple[Type, list[CheckError]] firstValue = inferPrimitive(values[0]);
      Type elemType = firstValue[0];
      list[CheckError] errors = firstValue[1];
      int i = 1;
      while (i < size(values)) {
        Primitive v = values[i];
        tuple[Type, list[CheckError]] inferred = inferPrimitive(v);
        errors += inferred[1];
        if (!compatible(elemType, inferred[0])) {
          errors += [typeMismatch(elemType, inferred[0])];
        }
        i += 1;
      }
      return <\listT(elemType), errors>;
    }
    case \map(values): {
      if (values == ()) {
        return <\mapT(stringT(), inferredT()), []>;
      }

      Type valueType = inferredT();
      list[CheckError] errors = [];
      bool first = true;
      for (key <- values) {
        tuple[Type, list[CheckError]] inferred = inferPrimitive(values[key]);
        errors += inferred[1];
        if (first) {
          valueType = inferred[0];
          first = false;
        }
        else if (!compatible(valueType, inferred[0])) {
          errors += [typeMismatch(valueType, inferred[0])];
        }
      }
      return <\mapT(stringT(), valueType), errors>;
    }
    case \enum(enumName, _): {
      return <\namedT(enumName), []>;
    }
  }

  return <inferredT(), []>;
}

tuple[Type, list[CheckError]] inferLValue(LValue lval, VarTable env, TypeTable types, StateTable states) {
  switch (lval) {
    case var(name): {
      if (name in env) {
        return <env[name], []>;
      }
      return <inferredT(), [unknownVariable(name)]>;
    }

    case field(var(owner), fieldName): {
      if (owner in types) {
        if (enumHasValue(fieldName, enumValuesOf(types[owner]))) {
          return <namedT(owner), []>;
        }
        return <inferredT(), [unknownEnumValue(owner, fieldName)]>;
      }

      if (owner in env) {
        return inferField(env[owner], fieldName, types, states);
      }

      return <inferredT(), [unknownVariable(owner)]>;
    }

    case field(lhs, fieldName): {
      tuple[Type, list[CheckError]] owner = inferLValue(lhs, env, types, states);
      tuple[Type, list[CheckError]] result = inferField(owner[0], fieldName, types, states);
      return <result[0], owner[1] + result[1]>;
    }

    case index(lhs, idx): {
      tuple[Type, list[CheckError]] owner = inferLValue(lhs, env, types, states);
      tuple[Type, list[CheckError]] indexType = inferExp(idx, env, types, states);
      list[CheckError] errors = owner[1] + indexType[1];

      switch (owner[0]) {
        case \listT(elemType): {
          if (!compatible(integerT(), indexType[0])) {
            errors += [typeMismatch(integerT(), indexType[0])];
          }
          return <elemType, errors>;
        }
        case \mapT(keyType, valueType): {
          if (!compatible(keyType, indexType[0])) {
            errors += [typeMismatch(keyType, indexType[0])];
          }
          return <valueType, errors>;
        }
        default:
          return <inferredT(), errors + [invalidOperand("index", owner[0])]>;
      }
    }
  }

  return <inferredT(), []>;
}

tuple[Type, list[CheckError]] inferField(Type ownerType, str fieldName, TypeTable types, StateTable states) {
  switch (ownerType) {
    case namedT(name): {
      if (name in states) {
        for (tuple[str, Type] field <- stateFieldsOf(states[name])) {
          if (field[0] == fieldName) {
            return <field[1], []>;
          }
        }
        return <inferredT(), [unknownField(ownerType, fieldName)]>;
      }

      if (name in types) {
        if (enumHasValue(fieldName, enumValuesOf(types[name]))) {
          return <namedT(name), []>;
        }
        return <inferredT(), [unknownEnumValue(name, fieldName)]>;
      }
    }
  }

  return <inferredT(), [unknownField(ownerType, fieldName)]>;
}

tuple[Type, list[CheckError]] inferCall(str name, list[Exp] params, VarTable env, TypeTable types, StateTable states) {
  if (name in states) {
    list[tuple[str, Type]] stateFlds = stateFieldsOf(states[name]);
    list[CheckError] errors = [];

    if (size(stateFlds) != size(params)) {
      errors += [wrongArity(name, size(stateFlds), size(params))];
    }

    int max = size(params);
    if (size(stateFlds) < size(params)) {
      max = size(stateFlds);
    }
    int i = 0;
    while (i < max) {
      tuple[str, Type] field = stateFlds[i];
      tuple[Type, list[CheckError]] arg = inferExp(params[i], env, types, states);
      errors += arg[1];
      if (!compatible(field[1], arg[0])) {
        errors += [typeMismatch(field[1], arg[0])];
      }
      i += 1;
    }

    return <namedT(name), errors>;
  }

  if (name == "min" || name == "max") {
    list[CheckError] errors = [];
    if (size(params) != 2) {
      errors += [wrongArity(name, 2, size(params))];
    }
    for (param <- params) {
      tuple[Type, list[CheckError]] arg = inferExp(param, env, types, states);
      errors += arg[1];
      if (!compatible(integerT(), arg[0])) {
        errors += [typeMismatch(integerT(), arg[0])];
      }
    }
    return <integerT(), errors>;
  }

  return <inferredT(), [unknownFunction(name)]>;
}

tuple[Type, list[CheckError]] inferNumericBinary(str op, Exp lhs, Exp rhs, VarTable env, TypeTable types, StateTable states) {
  tuple[Type, list[CheckError]] left = inferExp(lhs, env, types, states);
  tuple[Type, list[CheckError]] right = inferExp(rhs, env, types, states);
  list[CheckError] errors = left[1] + right[1];
  if (!compatible(integerT(), left[0])) {
    errors += [invalidOperand(op, left[0], "<left> <op> <right>")];
  }
  if (!compatible(integerT(), right[0])) {
    errors += [invalidOperand(op, right[0], "<left> <op> <right>")];
  }
  return <integerT(), errors>;
}

tuple[Type, list[CheckError]] inferComparison(str op, Exp lhs, Exp rhs, VarTable env, TypeTable types, StateTable states) {
  tuple[Type, list[CheckError]] numeric = inferNumericBinary(op, lhs, rhs, env, types, states);
  return <booleanT(), numeric[1]>;
}


tuple[Type, list[CheckError]] inferIsIn(str op, Exp lhs, Exp rhs, VarTable env, TypeTable types, StateTable states) {
  tuple[Type, list[CheckError]] left = inferExp(lhs, env, types, states);
  tuple[Type, list[CheckError]] right = inferExp(rhs, env, types, states);
  list[CheckError] errors = left[1] + right[1];
  switch (right[0]) {
    case mapT(keyType, _): {
      if (!compatible(left[0], keyType)) {
        errors += [invalidOperand(op, left[0], "<left> <op> <right>")];
      }
    }
    case listT(arrType): {
      if (!compatible(left[0], arrType)) {
        errors += [invalidOperand(op, right[0], "<left> <op> <right>")];
      }
    }
  }

  return <booleanT(), errors>;
}

tuple[Type, list[CheckError]] inferEquality(str op, Exp lhs, Exp rhs, VarTable env, TypeTable types, StateTable states) {
  tuple[Type, list[CheckError]] left = inferExp(lhs, env, types, states);
  tuple[Type, list[CheckError]] right = inferExp(rhs, env, types, states);
  list[CheckError] errors = left[1] + right[1];
  if (!compatible(left[0], right[0])) {
    errors += [invalidOperand(op, right[0], "<left> <op> <right>")];
  }
  return <booleanT(), errors>;
}

tuple[Type, list[CheckError]] inferBooleanBinary(str op, Exp lhs, Exp rhs, VarTable env, TypeTable types, StateTable states) {
  tuple[Type, list[CheckError]] left = inferExp(lhs, env, types, states);
  tuple[Type, list[CheckError]] right = inferExp(rhs, env, types, states);
  list[CheckError] errors = left[1] + right[1];
  if (!compatible(booleanT(), left[0])) {
    errors += [invalidOperand(op, left[0], "<left> <op> <right>")];
  }
  if (!compatible(booleanT(), right[0])) {
    errors += [invalidOperand(op, right[0], "<left> <op> <right>")];
  }
  return <booleanT(), errors>;
}

bool compatible(Type expected, Type actual) {
  if (expected == inferredT() || actual == inferredT()) {
    return true;
  }

  switch (<expected, actual>) {
    case <\listT(expectedElem), \listT(actualElem)>:
      return compatible(expectedElem, actualElem);
    case <\mapT(expectedKey, expectedValue), \mapT(actualKey, actualValue)>:
      return compatible(expectedKey, actualKey) && compatible(expectedValue, actualValue);
    case <\tupleT(expectedElems), \tupleT(actualElems)>: {
      if (size(expectedElems) != size(actualElems)) {
        return false;
      }

      int i = 0;
      while (i < size(expectedElems)) {
        if (!compatible(expectedElems[i], actualElems[i])) {
          return false;
        }
        i += 1;
      }
      return true;
    }
    default:
      return expected == actual;
  }
}

list[&T] concat(list[list[&T]] values) {
  list[&T] result = [];
  for (v <- values) {
    result += v;
  }
  return result;
}

bool enumHasValue(str fieldName, list[EnumValueDef] values) {
  for (EnumValueDef valueDef <- values) {
    switch (valueDef) {
      case enumValueDef(valueName, _): {
        if (valueName == fieldName) {
          return true;
        }
      }
    }
  }
  return false;
}

list[EnumValueDef] enumValuesOf(EnumDef enumDefinition) {
  switch (enumDefinition) {
    case enumDef(_, _, enumValues):
      return enumValues;
  }
  return [];
}

list[tuple[str, Type]] stateFieldsOf(State stateDefinition) {
  switch (stateDefinition) {
    case state(_, stateFields):
      return stateFields;
  }
  return [];
}
