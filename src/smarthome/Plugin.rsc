module smarthome::Plugin

import IO;

import util::Reflective;
import util::IDEServices;
import util::LanguageServer;

import smarthome::Server;
import smarthome::Parser;

// bool checkWellformedness(loc fil) {
//   // Parsing
//   &T resource = parseSystem(fil);
//   // Transform the parse tree into an abstract syntax tree
//   try &T ast = cst2ast(resource);
//   catch AssertionFailed(msg): {
//     // println(msg);
//     return false;
//   }
//   // Check the well-formedness of the program
//   return checkBoulderWallConfiguration(ast);
// }

int main() {
  // we register a new language to Rascal's LSP multiplexer
  // the multiplexer starts a new evaluator and loads this module and function
  registerLanguage(
    language(
      pathConfig(srcs=[|project://smarthome/src|]),
      "SmarthomeDSL",
      {"smrt"},
      "smarthome::Server",
      "contributions"
    )
  );
  return 0;
}

/*
 * Use this function to clear all traces of your language from VS code.
 */
void clearSmarthome() {
  unregisterLanguage("SmarthomeDSL", {"smrt"});
}

/*
 * Use this function to run your tests. It will show how many tests succeeded.
 * Note that an invalid test "succeeds" when the check fails
 */
void runTests() {
  fails = 0;
  validFiles = |project://smarthome/test/valid|.ls;
  invalidFiles = |project://smarthome/test/invalid|.ls;

  println("\nValid tests");
//   for (file <- validFiles) {
    // if (checkWellformedness(file)) {
    //   println("SUCCESS: <file.path> returns true");
    // } else {
    //   println("FAILURE: <file.path> returns false");
    //   fails += 1;
    // }
//   }

  println("\nInvalid tests");

//   for (file <- invalidFiles) {
    // if (checkWellformedness(file)) {
    //   println("FAILURE: <file.path> returns true");
    //   fails +=1;
    // } else {
    //   println("SUCCESS: <file.path> returns false");
    // }
//   }

  println("<fails> failed tests");
}
