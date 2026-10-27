// F2: what the generated graphs of test/src/analysis_support.dart reach over
// the 500 seeds, with the drafted analyses: the counts the property tests'
// floors are set from. Copied into the temporary tree's test/ by run.sh.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'analyze_graph_test.dart' show cleanGraph;
import 'src/analysis_support.dart';

void main() {
  test('generator statistics', () {
    int topologies = 0;
    int claims = 0;
    int edges = 0;
    int withCycle = 0;
    int withThree = 0;
    int selfFound = 0;
    int selfMediated = 0;
    int cleanSizable = 0;
    int cleanParts = 0;
    final List<int> kinds = <int>[0, 0, 0, 0];
    final Map<int, int> cleanSizes = <int, int>{};
    for (int seed = 0; seed < seeds; seed++) {
      final GraphParts parts = generatedParts(seed);
      final TopologyGraph g = graphOf(parts);
      topologies += g.topologies.length;
      claims += g.claims.length;
      for (final TopologyDefinition d in g.topologies) {
        edges += d.transforms.length;
        final int found = findSelfReferences(d).length;
        selfFound += found;
        selfMediated += d.reads.where(d.writes.contains).length - found;
      }
      final List<TopologyCycle> cycles = findTopologyCycles(g);
      withCycle += cycles.isEmpty ? 0 : 1;
      withThree += cycles.any((TopologyCycle c) => c.topologyIds.length > 2)
          ? 1
          : 0;
      kinds[0] += cycles.length;
      kinds[1] += <SelfReference>[
        for (final TopologyDefinition d in g.topologies)
          ...findSelfReferences(d),
      ].length;
      kinds[2] += findWriterConflicts(g).length;
      kinds[3] += findScopeViolations(g).length;
      final TopologyGraph clean = cleanGraph(parts);
      final int size = clean.topologies.length + clean.claims.length;
      cleanParts += size;
      cleanSizable += size >= 3 ? 1 : 0;
      cleanSizes[size] = (cleanSizes[size] ?? 0) + 1;
    }
    print(
      'F2 seeds: $seeds; topologies $topologies, claims $claims, edges $edges',
    );
    print(
      'F2 cycles: graphs with a cycle $withCycle, with a cycle of three or more $withThree',
    );
    print(
      'F2 self-reads: with an unmediated path $selfFound, without one $selfMediated',
    );
    print(
      'F2 findings by kind over all seeds (cycles, self-references, conflicts, violations): $kinds',
    );
    print(
      'F2 clean graphs: of three or more parts $cleanSizable; parts kept $cleanParts; by size ${(cleanSizes.keys.toList()..sort()).map((int k) => '$k:${cleanSizes[k]}').join(' ')}',
    );
  });
}
