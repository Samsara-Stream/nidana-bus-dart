// Runtime facts the nidana.model.8 plan relies on (S124). SDK only; run.sh
// runs it twice, in two processes, and compares the two outputs, so a line
// marked [run-dependent] is one whose value differs between runs.
//
//   H: which hash codes are stable across runs of the same program.
//   L: how Object.hash treats a List, and what Object.hashAll does instead.
//   U: List.unmodifiable copies; a const list is unmodifiable too.
//   X: the low 32 bits of a hash code as eight lowercase hex digits.
//   O: a Set literal and toSet() keep insertion order.
//   R: RegExp's `$` and a trailing newline.
//   A: RangeError is an ArgumentError (the matcher throwsArgumentError is
//      TypeMatcher<ArgumentError>).
//   T: how '$T' renders a type argument, nullable and nested ones included,
//      and Type equality across separate instantiations.
//   D: DateTime equality is instant and zone flag.

final class Box<T> {
  const Box();
  Type get type => T;
  String get rendered => '$T';
}

enum Variant { state, event }

void main() {
  print('H1 "abc".hashCode = ${'abc'.hashCode}');
  print('H2 Object.hash("a", 1) = ${Object.hash('a', 1)}');
  print('H3 Object.hash(1, 2) = ${Object.hash(1, 2)}');
  print('H4 (0x1234abcd).hashCode = ${0x1234abcd.hashCode}');
  print('H5 (-1).hashCode = ${(-1).hashCode}');
  print('H6 null.hashCode = ${null.hashCode}');
  print('H7 true.hashCode = ${true.hashCode}');
  print('H8 Variant.state.hashCode = ${Variant.state.hashCode}');
  print('H9 int (the Type).hashCode = ${(int).hashCode}');
  print('H10 DateTime.utc(2026).hashCode = ${DateTime.utc(2026).hashCode}');
  print('H11 Object.hashAll(["p-1", "p-2"]) = ${Object.hashAll(<String>['p-1', 'p-2'])}');
  print('H12 (0x71234abcd).hashCode = ${0x71234abcd.hashCode}');

  final List<String> a = <String>['p-1', 'p-2'];
  final List<String> b = <String>['p-1', 'p-2'];
  print('L1 a == b (two equal lists): ${a == b}');
  print('L2 Object.hash(a) == Object.hash(b): ${Object.hash(a, 0) == Object.hash(b, 0)}');
  print('L3 Object.hashAll(a) == Object.hashAll(b): ${Object.hashAll(a) == Object.hashAll(b)}');
  print('L4 Object.hashAll([p-2, p-1]) == Object.hashAll(a): ${Object.hashAll(<String>['p-2', 'p-1']) == Object.hashAll(a)}');
  print('L5 Object.hashAll([]) == Object.hashAll(const []): ${Object.hashAll(<String>[]) == Object.hashAll(const <String>[])}');

  final List<String> source = <String>['p-1'];
  final List<String> copy = List<String>.unmodifiable(source);
  source.add('p-2');
  print('U1 List.unmodifiable(source) after source.add: $copy');
  print('U2 copy.add throws: ${_throws(() => copy.add('x'))}');
  print('U3 const <String>[].add throws: ${_throws(() => const <String>[].add('x'))}');
  print('U4 identical(List.unmodifiable(copy), copy): ${identical(List<String>.unmodifiable(copy), copy)}');

  for (final int h in <int>[0x1234abcd, -1, 0xab, 0x71234abcd, 0]) {
    print('X ${h.toRadixString(16)} -> ${h.toUnsigned(32).toRadixString(16).padLeft(8, '0')}');
  }

  print('O1 <String>{b, a, b}.toList() = ${<String>{'b', 'a', 'b'}.toList()}');
  print('O2 [b, a, b, c].toSet().toList() = ${<String>['b', 'a', 'b', 'c'].toSet().toList()}');

  final RegExp segment = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');
  print('R1 segment matches "state": ${segment.hasMatch('state')}');
  print('R2 segment matches "state\\n": ${segment.hasMatch('state\n')}');
  print('R3 "auth.state\\n".split(".") = ${'auth.state\n'.split('.').map((String s) => s.replaceAll('\n', r'\n')).toList()}');
  print('R4 "".split(".") = ${''.split('.')} (length ${''.split('.').length})');
  print('R5 "auth..state".split(".") = ${'auth..state'.split('.')}');

  print('A1 RangeError.range(1, 0, 0) is ArgumentError: ${RangeError.range(1, 0, 0) is ArgumentError}');
  print('A2 RangeError.checkValidIndex(1, [x]) throws ArgumentError: ${_throwsArgumentError(() => RangeError.checkValidIndex(1, <int>[0]))}');
  print('A3 RangeError.checkValidIndex(-1, [x]) throws ArgumentError: ${_throwsArgumentError(() => RangeError.checkValidIndex(-1, <int>[0]))}');

  print('T1 ${const Box<int>().rendered} ${const Box<String?>().rendered} ${const Box<List<int>>().rendered} ${const Box<Map<String, List<int>?>>().rendered}');
  print('T2 Box<List<int>>().type == Box<List<int>>().type (separate instances): ${Box<List<int>>().type == Box<List<int>>().type}');
  print('T3 Box<int>().type == Box<int?>().type: ${Box<int>().type == Box<int?>().type}');
  print('T4 Box<Object?>().rendered = ${Box<Object?>().rendered}, Box<dynamic>().rendered = ${Box<dynamic>().rendered}');

  final DateTime utc = DateTime.utc(2026, 10, 27, 12);
  print('D1 utc == utc.toLocal(): ${utc == utc.toLocal()}; isAtSameMomentAs: ${utc.isAtSameMomentAs(utc.toLocal())}');
  print('D2 utc.toString() = $utc');
}

bool _throws(void Function() f) {
  try {
    f();
    return false;
  } on UnsupportedError {
    return true;
  }
}

bool _throwsArgumentError(void Function() f) {
  try {
    f();
    return false;
  } on ArgumentError catch (e) {
    return e is RangeError;
  }
}
