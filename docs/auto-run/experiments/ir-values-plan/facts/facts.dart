// Runtime facts the nidana.model.10 plan depends on (S134). Dart 3.13.5,
// `fvm dart run facts.dart`, run twice by ../run.sh (F1 and F2) so that a
// value that changes between runs shows as a difference.
//
//   H: how Object.hash treats a list, and what Object.hashAll does instead;
//      which hash codes are equal for equal values within one run.
//   U: Set.unmodifiable and List.unmodifiable: copy, order, rejection.
//   R: what FunctionRef.of's rule (the text between "from Function '" and
//      the next "'") yields for the forms the plan's tests use, beyond
//      docs/auto-run/experiments/function-ref-derivation/.
//   S: List.sort with a comparator over equal-comparing elements.
enum Variant { state, event, replay }

int topLevel(int v) => v;
int _private(int v) => v;
T identity<T>(T v) => v;

final class Statics {
  static int reduce(int s, int e) => s + e;
  static int _hidden(int s, int e) => s - e;
  static int Function(int) closureFromStatic() => (int v) => v;
}

final class Box {
  const Box(this.v);
  const Box.named(this.v);
  final int v;
}

final class Adder {
  const Adder();
  int call(int v) => v + 1;
}

final class Labeler {
  const Labeler();
  String label(int v) => '$v';
}

extension on int {
  int twice() => this * 2;
}

String? derive(Function f) {
  const String marker = "from Function '";
  final String text = f.toString();
  final int start = text.indexOf(marker);
  if (start < 0) return null;
  final int from = start + marker.length;
  final int end = text.indexOf("'", from);
  if (end < 0) return null;
  final String name = text.substring(from, end);
  return name.isEmpty ? null : name;
}

void main() {
  print('### H hashing');
  final List<int> a = <int>[1, 2];
  final List<int> b = <int>[1, 2];
  print('H1 [1,2] == [1,2] (two lists): ${a == b}');
  print('H2 Object.hash(0, a) == Object.hash(0, b): '
      '${Object.hash(0, a) == Object.hash(0, b)}');
  print('H3 Object.hash(0, Object.hashAll(a)) == '
      'Object.hash(0, Object.hashAll(b)): '
      '${Object.hash(0, Object.hashAll(a)) == Object.hash(0, Object.hashAll(b))}');
  print('H4 Object.hashAll([1, 2]) == Object.hashAll([2, 1]): '
      '${Object.hashAll(<int>[1, 2]) == Object.hashAll(<int>[2, 1])}');
  print('H5 Duration(ms: 5) == Duration(us: 5000), hashes equal: '
      '${const Duration(milliseconds: 5) == Duration(microseconds: int.parse('5000'))}, '
      '${const Duration(milliseconds: 5).hashCode == Duration(microseconds: int.parse('5000')).hashCode}');
  print('H6 values printed to compare between runs (F1 against F2):');
  print('   Object.hash("a", 1) = ${Object.hash('a', 1)}');
  print('   Object.hashAll(["a", 1]) = ${Object.hashAll(<Object>['a', 1])}');
  print('   "a".hashCode = ${'a'.hashCode}');
  print('   Variant.event.hashCode = ${Variant.event.hashCode}');
  print('   null.hashCode = ${null.hashCode}');
  print('   Object.hash(Variant.state, null) = ${Object.hash(Variant.state, null)}');

  print('### U unmodifiable copies');
  final List<String> source = <String>['c', 'a', 'b', 'a'];
  final Set<String> set = Set<String>.unmodifiable(source);
  final List<String> list = List<String>.unmodifiable(source);
  source.add('z');
  print('U1 Set.unmodifiable(["c","a","b","a"]) iterates: ${set.toList()}');
  print('U2 later change to the source reaches it: ${set.contains('z')}; '
      'the list copy: ${list.contains('z')}');
  try {
    set.add('q');
    print('U3 Set.unmodifiable add: no error');
  } on UnsupportedError catch (e) {
    print('U3 Set.unmodifiable add: UnsupportedError (${e.message})');
  }
  try {
    list.clear();
    print('U4 List.unmodifiable clear: no error');
  } on UnsupportedError catch (e) {
    print('U4 List.unmodifiable clear: UnsupportedError (${e.message})');
  }
  print('U5 runtimeType of the set: ${set.runtimeType}; of the list: '
      '${list.runtimeType}');
  print('U6 two unmodifiable sets with equal elements ==: '
      '${Set<String>.unmodifiable(<String>['a']) == Set<String>.unmodifiable(<String>['a'])}');

  print('### R FunctionRef.of rule');
  int local(int v) => v;
  final int Function(int) inVariable = (int v) => v;
  final List<(String, Function)> forms = <(String, Function)>[
    ('top-level', topLevel),
    ('private top-level', _private),
    ('static', Statics.reduce),
    ('private static', Statics._hidden),
    ('instance tear-off', const Labeler().label),
    ('generic uninstantiated', identity),
    ('generic instantiated', identity<int>),
    ('constructor tear-off', Box.new),
    ('named constructor tear-off', Box.named),
    ('implicit call tear-off', const Adder().call),
    ('extension tear-off', 3.twice),
    ('inline closure', (int v) => v),
    ('closure in a variable', inVariable),
    ('local function', local),
    ('closure from a static method', Statics.closureFromStatic()),
    ('closure calling a top-level function', (int v) => topLevel(v)),
  ];
  for (final (String label, Function f) in forms) {
    print('R ${label.padRight(38)}| ${f.toString().padRight(64)}| ${derive(f)}');
  }
  final Function implicitCall = identity<int Function(int)>(const Adder().call);
  print('R implicit call via Function-typed parameter | ${derive(implicitCall)}');
  print('R toString of a tear-off taken twice equal: '
      '${topLevel.toString() == topLevel.toString()}');

  print('### S sort');
  final List<String> words = <String>['b', 'B', 'a', 'A', 'b'];
  words.sort();
  print('S1 String.compareTo order of [b, B, a, A, b]: $words');
  print("S2 'String'.compareTo('int'): ${'String'.compareTo('int')}");
}
