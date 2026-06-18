// checkSmrt(|project://smarthome-dsl/test/idea/idea.smrt|);
module smarthome::Smrtcheck


import IO;
import String;

import smarthome::AST;
import smarthome::Checker;
import smarthome::Parser;

data ParsedSource
= parsedSourcePort(str sourceComponent, str sourcePort)
| parsedSourceHttpJson(str sourceUri)
;

FSM emptyFsm() = transition_list([], primCon(integer(0)), []);

Type buildType(str name) {
  switch (name) {
    case "int": return integer_t();
    case "str": return string_t();
    default: return named_t(name);
  }
}

System buildIdeaSystem() =
  system(
    [
      component(
        "ParkingController",
        [
          port("FROM_BARRIER", named_t("CarEvent")),
          port("TO_SIGNAL", named_t("SignalEvent"))
        ],
        emptyFsm()
      )
    ],
    [
      external_target_connection(
        portID("ParkingController", "TO_SIGNAL"),
        http_json("/signal")
      ),
      external_source_connection(
        http_json("/barrier"),
        portID("ParkingController", "FROM_BARRIER")
      )
    ]
  );

System buildSystem(loc file) {
  parseSmrt(file);

  str text = readFile(file);
  list[Component] components = [];
  list[Connection] connections = [];

  bool inComponents = false;
  bool inConnections = false;
  str currentComponent = "";
  list[Port] currentPorts = [];
  ParsedSource currentSource = parsedSourcePort("", "");

  for (line <- split("\n", text)) {
    if (/^[ \t]*components[ \t]*:/ := line) {
      inComponents = true;
      inConnections = false;
    }
    else if (/^[ \t]*connections[ \t]*:/ := line) {
      if (currentComponent != "") {
        components += [component(currentComponent, currentPorts, emptyFsm())];
        currentComponent = "";
        currentPorts = [];
      }

      inComponents = false;
      inConnections = true;
    }
    else if (/^[ \t]*types[ \t]*:/ := line) {
      if (currentComponent != "") {
        components += [component(currentComponent, currentPorts, emptyFsm())];
        currentComponent = "";
        currentPorts = [];
      }

      inComponents = false;
      inConnections = false;
    }
    else if (inComponents && /^[ \t]*<componentId:[A-Za-z][A-Za-z0-9_]*>[ \t]*:[ \t]*\{[ \t]*$/ := line) {
      if (currentComponent != "") {
        components += [component(currentComponent, currentPorts, emptyFsm())];
        currentPorts = [];
      }

      currentComponent = componentId;
    }
    else if (inComponents && currentComponent != "" && /^[ \t]*port[ \t]*\([ \t]*<portName:[A-Za-z][A-Za-z0-9_]*>[ \t]*,[ \t]*<typeName:[A-Za-z][A-Za-z0-9_]*>[ \t]*\)[ \t]*,/ := line) {
      currentPorts += [port(portName, buildType(typeName))];
    }
    else if (inConnections && /^[ \t]*source[ \t]*\([ \t]*<sourceComponent:[A-Za-z][A-Za-z0-9_]*>[ \t]*,[ \t]*<sourcePort:[A-Za-z][A-Za-z0-9_]*>[ \t]*\)[ \t]*,?/ := line) {
      currentSource = parsedSourcePort(sourceComponent, sourcePort);
    }
    else if (inConnections && /^[ \t]*source[ \t]*\([ \t]*http_json[ \t]*\([ \t]*\"<sourceUri:[^\"]*>\"[ \t]*\)[ \t]*\)[ \t]*,?/ := line) {
      currentSource = parsedSourceHttpJson(sourceUri);
    }
    else if (inConnections && /^[ \t]*target[ \t]*\([ \t]*<targetComponent:[A-Za-z][A-Za-z0-9_]*>[ \t]*,[ \t]*<targetPort:[A-Za-z][A-Za-z0-9_]*>[ \t]*\)[ \t]*,?/ := line) {
      switch (currentSource) {
        case parsedSourcePort(srcComponent, srcPort): {
          connections += [
            internal_connection(
              portID(srcComponent, srcPort),
              portID(targetComponent, targetPort)
            )
          ];
        }
        case parsedSourceHttpJson(srcUri): {
          connections += [
            external_source_connection(
              http_json(srcUri),
              portID(targetComponent, targetPort)
            )
          ];
        }
      }
    }
    else if (inConnections && /^[ \t]*target[ \t]*\([ \t]*http_json[ \t]*\([ \t]*\"<targetUri:[^\"]*>\"[ \t]*\)[ \t]*\)[ \t]*,?/ := line) {
      switch (currentSource) {
        case parsedSourcePort(srcComponent, srcPort): {
          connections += [
            external_target_connection(
              portID(srcComponent, srcPort),
              http_json(targetUri)
            )
          ];
        }
      }
    }
  }

  if (currentComponent != "") {
    components += [component(currentComponent, currentPorts, emptyFsm())];
  }

  return system(components, connections);
}

void checkIdea() {
  println(check(buildIdeaSystem()));
}

list[CheckError] checkSmrt(loc file) {
  return check(buildSystem(file));
}

void checkIdeaFile() {
  println(checkSmrt(|project://smarthome-dsl/test/idea/idea.smrt|));
}
