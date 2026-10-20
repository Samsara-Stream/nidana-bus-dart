// bus-api-v2 probe P1: which functions a topology's declare() can pass that
// compare == across two evaluations of declare (bus-api@v2 G23; Guide §6.3
// "Name every transformer"). Run: fvm dart run probe/function_equality.dart
int _double(int v) => v * 2;

final class Plain {
  Plain(this.k);
  final int k;
  int apply(int v) => v * k;
}

final class Valued {
  Valued(this.k);
  final int k;
  int apply(int v) => v * k;
  @override
  bool operator ==(Object other) => other is Valued && other.k == k;
  @override
  int get hashCode => k.hashCode;
}

final class Const {
  const Const(this.k);
  final int k;
  int apply(int v) => v * k;
}

final class Callable {
  const Callable(this.k);
  final int k;
  int call(int v) => v * k;
}

final class Statics {
  static int triple(int v) => v * 3;
}

int Function(int) declare(String kind, int k) => switch (kind) {
      'top-level tear-off' => _double,
      'static tear-off' => Statics.triple,
      'inline closure' => (int v) => v * k,
      'closure, no capture' => (int v) => v * 2,
      'tear-off on a new receiver' => Plain(k).apply,
      'tear-off on a new receiver with ==' => Valued(k).apply,
      'tear-off on a const receiver' => const Const(2).apply,
      'tear-off on an equal non-const receiver' => Const(k).apply,
      'callable object tear-off (.call)' => const Callable(2).call,
      _ => throw ArgumentError(kind),
    };

void main() {
  for (final kind in <String>[
    'top-level tear-off',
    'static tear-off',
    'inline closure',
    'closure, no capture',
    'tear-off on a new receiver',
    'tear-off on a new receiver with ==',
    'tear-off on a const receiver',
    'tear-off on an equal non-const receiver',
    'callable object tear-off (.call)',
  ]) {
    final a = declare(kind, 2);
    final b = declare(kind, 2);
    print('${kind.padRight(40)} two evaluations ==: ${a == b}');
  }
}
