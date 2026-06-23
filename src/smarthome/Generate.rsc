module smarthome::Generate

import IO;
import List;
import String;

import smarthome::Generator;

public int main(list[str] args) {
  if (size(args) != 2) {
    println("Usage: generate input.smrt output.py");
    return 1;
  }

  loc input = fileLoc(args[0]);
  loc output = fileLoc(args[1]);

  generatePythonFile(input, output);
  println("Generated <output>");
  return 0;
}

loc fileLoc(str uriOrPath) {
  str normalized = replaceAll(uriOrPath, "\\", "/");
  return |file:///<normalized>|;
}
