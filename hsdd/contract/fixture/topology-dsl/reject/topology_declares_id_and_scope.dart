// Reject fixture for topology-dsl@v1 G7: a topology declares its identifier,
// its scope and its body (Spec §4.6, §6.1, §7.2). The builder form takes all
// three; a class that leaves one out does not compile.
// covers: G7
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// expect-diagnostic: not_enough_positional_arguments
final Topology unscoped = topology('checkout-flow', Scope.module);

// expect-diagnostic: non_abstract_class_inherits_abstract_member
final class NoScope extends Topology {
  @override
  String get topologyId => 'checkout-flow';

  @override
  void declare(TopologyBuilder b) {}
}

// expect-diagnostic: non_abstract_class_inherits_abstract_member
final class NoId extends Topology {
  @override
  Scope get scope => Scope.module;

  @override
  void declare(TopologyBuilder b) {}
}

// expect-diagnostic: non_abstract_class_inherits_abstract_member
final class NoBody extends Topology {
  @override
  String get topologyId => 'checkout-flow';

  @override
  Scope get scope => Scope.module;
}

// expect-diagnostic: argument_type_not_assignable
final TopologyRef numbered = TopologyRef(7);
