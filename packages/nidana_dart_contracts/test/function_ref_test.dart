// topology-ir@v1's function references, beyond the G9 cases of its
// conformance suite, which the gate replays: the other forms of the
// Function references table, the rendering of private names, the empty-name
// error, and value equality (G7, which joins the gate at nidana.model.11).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

int topLevel(int v) => throw StateError('FunctionRef.of called topLevel');
T identity<T>(T v) => v;

final class Box {
  const Box(this.v);
  const Box.named(this.v);
  final int v;
}

final class _Hidden {
  const _Hidden();
  String _format(int v) => '$v';
}

final class Adder {
  const Adder();
  int call(int v) => v + 1;
}

final class Statics {
  static int Function(int) closure() =>
      (int v) => v;
}

extension on int {
  int twice() => this * 2;
}

void main() {
  test('G9 FunctionRef.of names a constructor tear-off, a generic function '
      'and a call tear-off as the VM renders them', () {
    expect(FunctionRef.of(Box.new).name, 'Box.');
    expect(FunctionRef.of(Box.named).name, 'Box.named');
    expect(FunctionRef.of(identity).name, 'identity');
    expect(FunctionRef.of(identity<int>).name, 'identity');
    expect(FunctionRef.of(const Adder().call).name, 'call');
  });

  test('G9 FunctionRef.of keeps the library key after a private class, '
      'constructor and method name', () {
    expect(
      FunctionRef.of(_Hidden.new).name,
      matches(RegExp(r'^_Hidden@\d+\.$')),
    );
    expect(
      FunctionRef.of(const _Hidden()._format).name,
      matches(RegExp(r'^_format@\d+$')),
    );
  });

  test('G9 FunctionRef.of is anonymous for an extension method tear-off, a '
      'closure a static method returns, and a closure that calls a named '
      'function', () {
    expect(FunctionRef.of(3.twice), const FunctionRef.anonymous());
    expect(FunctionRef.of(Statics.closure()), const FunctionRef.anonymous());
    expect(
      FunctionRef.of((int v) => topLevel(v)),
      const FunctionRef.anonymous(),
    );
    expect(FunctionRef.of(topLevel).name, 'topLevel');
  });

  test('G9 FunctionRef.of and FunctionRef.named agree on a public name', () {
    expect(FunctionRef.of(topLevel), FunctionRef.named('topLevel'));
    expect(
      FunctionRef.of(topLevel).hashCode,
      FunctionRef.named('topLevel').hashCode,
    );
  });

  test('G9 FunctionRef.named keeps any non-empty name and throws '
      'ArgumentError naming the argument for an empty one', () {
    expect(FunctionRef.named(' ').name, ' ');
    expect(FunctionRef.named('a b').name, 'a b');
    expect(
      () => FunctionRef.named(''),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.name,
          'name',
          'name',
        ),
      ),
    );
  });

  test('G7 function references are equal, with equal hash codes, exactly '
      'when their names are', () {
    expect(FunctionRef.named('a'), FunctionRef.named('a'));
    expect(FunctionRef.named('a').hashCode, FunctionRef.named('a').hashCode);
    expect(FunctionRef.named('a'), isNot(FunctionRef.named('b')));
    expect(FunctionRef.named('a'), isNot(FunctionRef.named('A')));
    expect(
      FunctionRef.of((int v) => v).hashCode,
      const FunctionRef.anonymous().hashCode,
    );
    expect(<FunctionRef>{
      FunctionRef.named('a'),
      FunctionRef.named('a'),
      const FunctionRef.anonymous(),
      FunctionRef.of((int v) => v),
    }, hasLength(2));
  });

  test('G7 a function reference is equal to no other kind of object', () {
    final Object text = 'a';
    final Object nothing = Object();
    expect(FunctionRef.named('a') == text, isFalse);
    expect(const FunctionRef.anonymous() == nothing, isFalse);
  });

  test('G9 FunctionRef.of renders one tear-off taken twice as one name, and '
      'FunctionRef.named reports the empty value it rejected', () {
    expect(FunctionRef.of(topLevel), FunctionRef.of(topLevel));
    expect(FunctionRef.of(Box.named), FunctionRef.of(Box.named));
    expect(
      () => FunctionRef.named(''),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.invalidValue,
          'invalidValue',
          '',
        ),
      ),
    );
  });
}
