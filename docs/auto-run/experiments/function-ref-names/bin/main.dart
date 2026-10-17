// Question (for Spec §6.5 FunctionRef): can a topology recorder name a
// transformer from the function value alone, in JIT and in AOT?
int buildTotal(int a, int b) => a + b;

class Reducers {
  static int reduceCount(int s, String e) => s + 1;
}

void main() {
  print('top-level tear-off : $buildTotal');
  print('static tear-off    : ${Reducers.reduceCount}');
  print('inline closure     : ${(int x) => x * 2}');
  print('identical tear-offs: ${identical(buildTotal, buildTotal)} equal: ${buildTotal == buildTotal}');
}
