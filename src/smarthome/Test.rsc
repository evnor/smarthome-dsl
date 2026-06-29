module smarthome::Test

import IO;
import List;
import String;
import Exception;

import smarthome::Generator;

public int main() {
  fails = 0;
  validFiles = |project://smarthome-dsl/test/valid|.ls;
  invalidFiles = |project://smarthome-dsl/test/invalid|.ls;

  println("Valid files");
  for (file <- validFiles) {
    success = true;
    code = "";
    try {
      <success, code> = generatePythonFile(file);
    } catch ParseError(e): {
      fails += 1;
      println("PARSE ERROR: <file>\n    <e>");
      continue;
    }
    if (success) {
      println("SUCCESS: <file>");
    } else {
      println("FAILED: <file>");
      println(code);
      fails += 1;
    }
  }

  println("Invalid files");
  for (file <- invalidFiles) {
    success = true;
    code = "";
    try {
      <success, code> = generatePythonFile(file);
    } catch ParseError(e): {
      fails += 1;
      println("PARSE ERROR: <file>\n    <e>");
      continue;
    }
    if (!success) {
      println("SUCCESS: <file>");
    } else {
      println("FAILED: <file>");
      fails += 1;
    }
  }

  println("<fails> failed tests");
  return 0;
}