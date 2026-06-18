// minimal checker for channel types and connections
module smarthome::Checker

import smarthome::AST;

data CheckError
  = unknownComponent(str component)
  | unknownPort(str component, str port)
  | cannotInferConnectionType(Connection connection)
  | cannotInferChannelType(Connection connection)
  ;

data CheckedConnection
= checked_internal_connection(PortID sourcePort, PortID targetPort, Type dt, ChannelType ct)
| checked_external_source_connection(ExternalSourcePort externalSource, PortID targetPort, Type dt, ChannelType ct)
| checked_external_target_connection(PortID sourcePort, ExternalTargetPort externalTarget, Type dt, ChannelType ct);

alias PortTable = map[tuple[str component, str port], Type];

PortTable collectPorts(System sys) {
  PortTable table = ();

  for (component(id, ports, _) <- sys.components) {
    for (port(name, tp) <- ports) {
      table += (<id, name>: tp);
    }
  }

  return table;
}

list[CheckError] check(System sys) {
  PortTable ports = collectPorts(sys);
  list[CheckError] errors = [];

  for (conn <- sys.connections) {
    errors += checkConnection(conn, ports);
  }

  return errors;
}

list[CheckError] checkConnection(Connection conn, PortTable ports) {
  switch (conn) {
    case internal_connection(portID(srcComp, srcPort), portID(dstComp, dstPort)): {
      list[CheckError] errors = [];

      if (<srcComp, srcPort> notin ports) {
        errors += [unknownPort(srcComp, srcPort)];
      }

      if (<dstComp, dstPort> notin ports) {
        errors += [unknownPort(dstComp, dstPort)];
      }

      if (errors != []) {
        return errors;
      }

      if (ports[<srcComp, srcPort>] != ports[<dstComp, dstPort>]) {
        return [cannotInferConnectionType(conn)];
      }

      return [];
    }

    case external_source_connection(_, portID(dstComp, dstPort)): {
      if (<dstComp, dstPort> notin ports) {
        return [unknownPort(dstComp, dstPort)];
      }

      return [];
    }

    case external_target_connection(portID(srcComp, srcPort), _): {
      if (<srcComp, srcPort> notin ports) {
        return [unknownPort(srcComp, srcPort)];
      }

      return [];
    }
  }

  return [];
}
