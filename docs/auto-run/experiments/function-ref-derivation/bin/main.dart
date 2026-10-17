// Question (topology-ir@v1, OQ-M1): which function forms does a derivation
// from Function.toString() name, under each compiler the tree can meet?
//
// Two derivations are printed after the toString() text:
//   vm   the text between "from Function '" and the next "'"; anonymous
//        (null) when absent or empty. This is what topology-ir@v1 adopts.
//   +js  the same, falling back to the text of a dart2js "Closure '...'"
//        prefix. Rejected: dart2js names inline closures (main_closure).

int buildTotal(int a, int b) => a + b;

T identity<T>(T value) => value;

class Reducers {
  static int reduceCount(int s, String e) => s + 1;
}

class Formatter {
  const Formatter(this.prefix);
  final String prefix;
  String format(int v) => '$prefix$v';
}

class Adder {
  const Adder(this.n);
  final int n;
  int call(int v) => v + n;
}

extension on int {
  int twice() => this * 2;
}

final class Box {
  const Box(this.v);
  final int v;
}

String? deriveVm(Function f) {
  final m = RegExp(r"from Function '([^']*)'").firstMatch(f.toString());
  final name = m?.group(1);
  return name == null || name.isEmpty ? null : name;
}

String? deriveWithJs(Function f) {
  final vm = deriveVm(f);
  if (vm != null) return vm;
  final m = RegExp(r"^Closure '([^']*)'").firstMatch(f.toString());
  final name = m?.group(1);
  return name == null || name.isEmpty ? null : name;
}

void show(String label, Function f) {
  print('${label.padRight(27)}| ${f.toString().padRight(68)}'
      '| vm ${'${deriveVm(f)}'.padRight(12)}| +js ${deriveWithJs(f)}');
}

void main() {
  int localHelper(int v) => v + 1;
  final assignedClosure = (int v) => v - 1;
  const formatter = Formatter('#');
  const adder = Adder(3);
  int Function(int) callTearOff = adder; // implicit call tear-off
  int Function(int) instantiated = identity; // generic instantiation
  int Function() extensionTearOff = 4.twice;
  show('top-level tear-off', buildTotal);
  show('static method tear-off', Reducers.reduceCount);
  show('instance method tear-off', formatter.format);
  show('local named function', localHelper);
  show('inline closure', (int v) => v * 2);
  show('closure in a variable', assignedClosure);
  show('generic, uninstantiated', identity);
  show('generic, instantiated', instantiated);
  show('constructor tear-off', Box.new);
  show('implicit call tear-off', callTearOff);
  show('extension method tear-off', extensionTearOff);
  print('same tear-off identical: ${identical(buildTotal, buildTotal)}; '
      'two closure evaluations equal: '
      '${_make() == _make()}');
}

int Function(int) _make() => (int v) => v;
