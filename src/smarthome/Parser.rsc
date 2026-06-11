module smarthome::Parser

import ParseTree;
import IO;

import smarthome::Syntax;

start[System] parseSystem(loc filePath) {
  return parse(#start[System], readFile(filePath));
}

Func parseFunc(loc filePath) {
  return parse(#Func, readFile(filePath));
}
