module smarthome::tests
import smarthome::Parser;

import IO;

test bool func_dot_smrt() {
    parseSmrt(|project://smarthome-dsl/test/func.smrt|);
    return true;
}

void main() {
    print(func_dot_smrt());
}