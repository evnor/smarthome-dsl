module smarthome::Parser

import ParseTree;
import IO;

import smarthome::Syntax;

start[System] parseSmrt(loc filePath) {
  return parse(#start[System], readFile(filePath));
}
