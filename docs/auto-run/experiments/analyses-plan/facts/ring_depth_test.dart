// F1: how deep the draft's recursive Tarjan search can go under dart test:
// one ring of n topologies needs a search n calls deep. Copied into the
// temporary tree's test/ by run.sh, never into the package.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

TopicRef ring(int i) =>
    TopicRef(name: 'ring.$i', variant: TopicVariant.event, typeName: 'int');

void main() {
  for (final int n in <int>[3000, 10000, 30000, 100000, 300000]) {
    test('ring of $n', () {
      final Stopwatch built = Stopwatch()..start();
      final TopologyGraph g = TopologyGraph(
        topologies: <TopologyDefinition>[
          for (int i = 0; i < n; i++)
            TopologyDefinition(
              topologyId: 'r${i.toString().padLeft(6, '0')}',
              scope: Scope.page,
              transforms: <TransformEdge>[
                TransformEdge.write(ring((i + 1) % n), TopicInput(ring(i))),
              ],
            ),
        ],
      );
      final int buildMs = built.elapsedMilliseconds;
      final Stopwatch searched = Stopwatch()..start();
      try {
        final List<TopologyCycle> cycles = findTopologyCycles(g);
        print(
          'F1 ring $n: ${cycles.length} cycle of '
          '${cycles.single.topologyIds.length} ids; graph built in $buildMs ms, '
          'cycles found in ${searched.elapsedMilliseconds} ms',
        );
      } on StackOverflowError {
        print(
          'F1 ring $n: StackOverflowError after ${searched.elapsedMilliseconds} ms',
        );
      }
    });
  }
}
