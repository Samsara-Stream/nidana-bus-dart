// generate {input} {output}: copies {input}/in.txt to {output}/in.txt.
import 'dart:io';

void main(List<String> arguments) {
  File('${arguments[0]}/in.txt').copySync('${arguments[1]}/in.txt');
}
