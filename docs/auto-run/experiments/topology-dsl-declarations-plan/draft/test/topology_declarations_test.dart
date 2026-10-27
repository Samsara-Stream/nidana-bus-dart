// What the declarations of topology-dsl@v2's main library fix before any
// body computes (nidana.model D3): a topology in class form is inert data,
// and a topology reference keeps its id.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

final class Unrecorded extends Topology {
  const Unrecorded();

  @override
  String get topologyId => 'unrecorded';

  @override
  Scope get scope => Scope.page;

  @override
  void declare(TopologyBuilder b) =>
      throw StateError('declare ran outside planOf');
}

void main() {
  test('G9 constructing a topology in class form never runs declare', () {
    late final Topology declared;
    expect(() => declared = Unrecorded(), returnsNormally);
    expect(declared.topologyId, 'unrecorded');
    expect(declared.scope, Scope.page);
  });

  test('G7 a TopologyRef keeps the id it is given', () {
    expect(const TopologyRef('checkout-flow').id, 'checkout-flow');
  });
}
