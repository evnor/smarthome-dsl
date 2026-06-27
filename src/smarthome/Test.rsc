module smarthome::Test

import IO;
import List;
import String;

import smarthome::Generator;

public int main() {
  fails = 0;
  validFiles = |project://smarthome-dsl/test/valid|.ls;
  invalidFiles = |project://smarthome-dsl/test/invalid|.ls;

  println("Valid files");
  for (file <- validFiles) {
    success = true;
    try {
      str code = generatePythonFile(file);
    } catch str e: {
      success = false;
    }
    if (success) {
      println("SUCCESS: <file>");
    } else {
      println("FAILED: <file>");
      fails += 1;
    }
  }

  println("Invalid files");
  for (file <- invalidFiles) {
    success = true;
    try {
      str code = generatePythonFile(file);
    } catch str e: {
      success = false;
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