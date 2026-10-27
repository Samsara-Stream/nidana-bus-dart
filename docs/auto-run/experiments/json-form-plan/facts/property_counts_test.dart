// F4 of json-form-plan: what the property tests' generators reach over their
// 500 seeds, against whichever codec.dart the temporary workspace holds:
// mutated documents and definition objects that decode, that are rejected
// with a FormatException, and that throw anything else (by type), and the
// same for arbitrary values. run.sh copies it into test/ beside
// json_reject_test.dart, whose generators it imports.
import 'dart:convert';
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'json_reject_test.dart' as reject;
import 'src/json_support.dart';

String kind(Object outcome) => switch (outcome) {
  TopologyGraph() || TopologyDefinition() => 'decoded',
  FormatException() => 'FormatException',
  _ => outcome.runtimeType.toString(),
};

void main() {
  test('F4 outcome counts', () {
    final Map<String, int> documents = <String, int>{};
    final Map<String, int> definitions = <String, int>{};
    final Map<String, int> arbitrary = <String, int>{};
    final Set<int> leakingSeeds = <int>{};
    for (int seed = 0; seed < seeds; seed++) {
      final Random random = Random(seed);
      final TopologyGraph g = generatedGraph(seed);
      final Object? doc = jsonDecode(jsonEncode(encodeTopologyGraph(g)));
      for (int i = 0, n = 1 + random.nextInt(3); i < n; i++) {
        reject.mutate(random, doc);
      }
      final String k = kind(reject.decodeOutcome(doc, decodeTopologyGraph));
      documents.update(k, (int v) => v + 1, ifAbsent: () => 1);
      if (k != 'decoded' && k != 'FormatException') {
        leakingSeeds.add(seed);
      }
      for (final TopologyDefinition d in g.topologies) {
        final Object? object = jsonDecode(
          jsonEncode(encodeTopologyDefinition(d)),
        );
        reject.mutate(random, object);
        final String dk = kind(
          reject.decodeOutcome(object, decodeTopologyDefinition),
        );
        definitions.update(dk, (int v) => v + 1, ifAbsent: () => 1);
      }
      final String ak = kind(
        reject.decodeOutcome(
          reject.arbitrary(Random(seed), 4),
          decodeTopologyGraph,
        ),
      );
      arbitrary.update(ak, (int v) => v + 1, ifAbsent: () => 1);
    }
    print('F4 mutated documents: $documents');
    print('F4 mutated definition objects: $definitions');
    print('F4 arbitrary values: $arbitrary');
    print(
      'F4 seeds whose document throws something else: ${leakingSeeds.length}'
      '${leakingSeeds.isEmpty ? '' : ', the first ${leakingSeeds.take(5).toList()}'}',
    );
    int graphs = 0;
    int topologies = 0;
    int edges = 0;
    int claims = 0;
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      graphs++;
      topologies += g.topologies.length;
      claims += g.claims.length;
      for (final TopologyDefinition d in g.topologies) {
        edges += d.transforms.length;
      }
    }
    print(
      'F4 generated: $graphs graphs, $topologies topologies, $edges edges, '
      '$claims claims',
    );
  });
}
