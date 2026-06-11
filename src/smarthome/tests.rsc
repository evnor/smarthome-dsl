module smarthome::tests
import smarthome::Parser;

import IO;

test bool func_dot_smrt() {
    parseFunc(|project://smarthome/test/func.f|);
    return true;
}

void main() {
    print(func_dot_smrt());
}