module smarthome::tests
import smarthome::Parser;

import IO;

test bool idea_dot_smrt() {
    parseSmrt(|project://smarthome-dsl/test/idea/idea.smrt|);
    return true;
}

void main() {
    print(idea_dot_smrt());
}