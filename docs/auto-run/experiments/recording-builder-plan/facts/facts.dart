// Runtime facts the nidana.model.9 plan depends on (S127). Standalone: dart:
// libraries only, run with `fvm dart run facts.dart` from this directory.
//
// I  identity: which references to a function or a Duration are identical
//    when evaluated twice, so a test knows what `same(...)` can assert.
// Z  zone interception: what a ZoneSpecification counts, so a test that
//    asserts "no timer and no microtask" has a positive control.
// V  type arguments: a visitor reached through a private method the stage
//    class implements (double dispatch) binds the stage's own type
//    arguments; a pattern over the erased type does not, and reading a
//    function-typed member through it fails at run time.
// C  combineAll's apply: a List<Object?> handed to a List<int> combiner
//    fails; a typed copy made inside a closure captured at construction
//    works and can be unmodifiable.
import 'dart:async';

int topLevel(int v) => v + 1;

T generic<T>(T v) => v;

final class Holder {
  int method(int v) => v;
  static int staticMethod(int v) => v;
}

// ---------------------------------------------------------------- V

sealed class Stage<T> {
  Stage._();
  V _accept<V>(Visitor<V> visitor);
}

final class MapStage<T, R> extends Stage<R> {
  MapStage._(this.transform) : super._();
  final R Function(T value) transform;
  @override
  V _accept<V>(Visitor<V> visitor) => visitor.map<T, R>(this);
}

final class PairStage<T> extends Stage<({T previous, T current})> {
  PairStage._() : super._();
  @override
  V _accept<V>(Visitor<V> visitor) => visitor.pair<T>(this);
}

abstract interface class Visitor<V> {
  V map<T, R>(MapStage<T, R> stage);
  V pair<T>(PairStage<T> stage);
}

final class TypeArgs implements Visitor<String> {
  @override
  String map<T, R>(MapStage<T, R> stage) => 'map<$T, $R>';
  @override
  String pair<T>(PairStage<T> stage) => 'pair<$T>';
}

/// What an interpreter builds: a function over Object? that applies the
/// stage's transform at the stage's own types.
final class Adapter implements Visitor<Object? Function(Object?)> {
  @override
  Object? Function(Object?) map<T, R>(MapStage<T, R> stage) =>
      (Object? v) => stage.transform(v as T);
  @override
  Object? Function(Object?) pair<T>(PairStage<T> stage) => (Object? v) => v;
}

V visit<V>(Stage<Object?> stage, Visitor<V> visitor) => stage._accept(visitor);

String patternRead(Stage<Object?> stage) {
  switch (stage) {
    case MapStage<Object?, Object?>():
      final Object? Function(Object?) f = stage.transform;
      return 'read ${f.runtimeType}';
    case PairStage<Object?>():
      return 'pair';
  }
}

String attempt(String label, Object? Function() f) {
  try {
    return '$label: ${f()}';
  } catch (e) {
    return '$label: throws ${e.runtimeType}';
  }
}

// ---------------------------------------------------------------- C

R applyErased<T, R>(R Function(List<T> values) combiner, List<Object?> values) =>
    (combiner as dynamic)(values) as R;

void main() {
  // I identity
  print('I1 top-level tear-off twice identical: ${identical(topLevel, topLevel)}');
  print('I2 static method tear-off twice identical: '
      '${identical(Holder.staticMethod, Holder.staticMethod)}');
  final Holder h = Holder();
  print('I3 instance method tear-off twice identical: '
      '${identical(h.method, h.method)}, equal: ${h.method == h.method}');
  int local(int v) => v;
  print('I4 local function tear-off twice identical: ${identical(local, local)}');
  final List<int Function(int)> closures = <int Function(int)>[(int v) => v];
  print('I5 closure literal read twice from one list identical: '
      '${identical(closures[0], closures[0])}');
  print('I6 the same closure literal evaluated twice identical: '
      '${identical(<int Function(int)>[for (int i = 0; i < 2; i++) (int v) => v][0], <int Function(int)>[for (int i = 0; i < 2; i++) (int v) => v][1])}');
  final int Function(int) instantiated = generic;
  final int Function(int) instantiatedAgain = generic;
  print('I7 generic top-level instantiated twice identical: '
      '${identical(instantiated, instantiatedAgain)}');
  print('I8 const Duration twice identical: '
      '${identical(const Duration(milliseconds: 1), const Duration(milliseconds: 1))}');
  final int ms = <int>[1].single;
  final Duration d = Duration(milliseconds: ms);
  print('I9 non-const Duration built apart identical: '
      '${identical(d, Duration(milliseconds: ms))}, equal: ${d == Duration(milliseconds: ms)}');
  final Object? Function(int) widened = topLevel;
  print('I10 a function stored at a wider function type stays identical: '
      '${identical(widened, topLevel)}');
  final Function asFunction = topLevel;
  print('I11 a function stored as Function stays identical: '
      '${identical(asFunction, topLevel)}');

  // Z zone interception
  int counted = 0;
  final ZoneSpecification spec = ZoneSpecification(
    createTimer: (Zone self, ZoneDelegate parent, Zone zone, Duration duration,
        void Function() f) {
      counted++;
      return parent.createTimer(zone, duration, f);
    },
    createPeriodicTimer: (Zone self, ZoneDelegate parent, Zone zone,
        Duration period, void Function(Timer timer) f) {
      counted++;
      return parent.createPeriodicTimer(zone, period, f);
    },
    scheduleMicrotask:
        (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
      counted++;
      parent.scheduleMicrotask(zone, f);
    },
  );
  final List<(String, void Function())> probes = <(String, void Function())>[
    ('Z1 nothing', () {}),
    ('Z2 Timer(Duration.zero, ...) then cancel', () => Timer(Duration.zero, () {}).cancel()),
    ('Z3 Timer.periodic then cancel', () => Timer.periodic(const Duration(seconds: 1), (Timer t) {}).cancel()),
    ('Z4 scheduleMicrotask', () => scheduleMicrotask(() {})),
    ('Z5 Future<int>.value(1)', () => Future<int>.value(1)),
    ('Z6 Future<int>.value(1).then', () => Future<int>.value(1).then((int v) => v)),
    ('Z7 Completer<int>().complete(1)', () => Completer<int>().complete(1)),
    ('Z8 Stream<int>.value(1) (not listened)', () => Stream<int>.value(1)),
    ('Z9 StreamController<int>() (not listened)', () => StreamController<int>()),
    ('Z10 a sync throw propagates out of runZoned', () => throw StateError('x')),
  ];
  for (final (String label, void Function() body) in probes) {
    counted = 0;
    String outcome = 'returns';
    try {
      runZoned(body, zoneSpecification: spec);
    } catch (e) {
      outcome = 'throws ${e.runtimeType}';
    }
    print('$label: counted $counted, $outcome');
  }

  // V type arguments
  final List<Stage<Object?>> stages = <Stage<Object?>>[
    MapStage<int, String>._((int v) => '$v!'),
    PairStage<List<int>>._(),
  ];
  for (final Stage<Object?> s in stages) {
    print('V1 visit through _accept: ${visit(s, TypeArgs())}');
  }
  print(attempt('V2 the adapter applies map<int, String> to 3',
      () => visit(stages[0], Adapter())(3)));
  print(attempt('V3 the adapter applied to a String fails', () => visit(stages[0], Adapter())('x')));
  print(attempt('V4 reading transform through a MapStage<Object?, Object?> pattern',
      () => patternRead(stages[0])));
  print('V5 MapStage<int, String> is MapStage<Object?, Object?>: '
      '${stages[0] is MapStage<Object?, Object?>}');

  // C combineAll's apply
  int sum(List<int> values) => values.fold(0, (int a, int b) => a + b);
  print(attempt('C1 a List<Object?> handed to a List<int> combiner', () => applyErased<int, int>(sum, <Object?>[1, 2])));
  int Function(List<Object?>) typed<T>(int Function(List<T>) combiner) =>
      (List<Object?> values) => combiner(List<T>.unmodifiable(values.cast<T>()));
  print(attempt('C2 a typed unmodifiable copy made in a captured closure', () => typed<int>(sum)(<Object?>[1, 2])));
  List<int>? seen;
  int keep(List<int> values) {
    seen = values;
    return 0;
  }
  typed<int>(keep)(<Object?>[1, 2]);
  print(attempt('C3 the combiner sees a List<int>', () => seen is List<int>));
  print(attempt('C4 the combiner list rejects add', () {
    seen!.add(3);
    return 'added';
  }));
  print(attempt('C5 a String among the values fails the copy', () => typed<int>(sum)(<Object?>[1, 'x'])));
}
