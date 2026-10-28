// Which unused private constructors does unused_element report, and is an
// implicit default constructor const? (S112, nidana.model.4 plan)
part 'constructors_part.dart';

/// A sealed base whose only constructor is private, as TopicStream and
/// PlanSink are.
sealed class Handle<T> {
  Handle._();
}

/// The only constructor is private and nothing calls it, as
/// TopologyBuilder and TopologyPlan while planOf throws: not reported.
final class OnlyPrivate {
  OnlyPrivate._();
}

/// A stage class whose only constructor is private and unused: not reported.
final class Stage<T> extends Handle<T> {
  Stage._(this.input) : super._();
  final Handle<T> input;
}

/// A private generative constructor beside a factory that throws, as
/// TransformEdge and TopologyDefinition: reported.
final class PrivateBesideFactory {
  PrivateBesideFactory._(this.x);
  factory PrivateBesideFactory.of(int y) => throw UnimplementedError();
  final int x;
}

/// A const constructor over a base with no declared constructor: reported,
/// so EdgeInput declares const EdgeInput._().
class Base {}

class Sub extends Base {
  const Sub();
}

/// A typed initializing formal narrower than its field, as
/// FunctionRef.named(String this.name) over String? name: accepted.
final class Named {
  Named.named(String this.name);
  const Named.anonymous() : name = null;
  final String? name;
}
