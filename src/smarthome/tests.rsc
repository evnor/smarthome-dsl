module smarthome::tests
import smarthome::Parser;
import smarthome::Syntax;

import IO;
import vis::Text;

test bool idea_dot_smrt() {
    start[System] tree = parseSmrt(|project://smarthome-dsl/test/idea/idea.smrt|);
    println(prettyTree(tree));
    return true;
}

void main() {
    print(idea_dot_smrt());
}