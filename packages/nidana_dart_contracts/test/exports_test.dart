// The three public libraries export exactly the names their contracts place
// in them (topology-dsl@v2 G2; topology-ir@v1's Libraries; nidana.model D4),
// so a declaration cannot leak from one library into another.
import 'dart:io';

import 'package:test/test.dart';

import 'src/package_files.dart';

/// The names the export directives of [source] show, or null when one of
/// them has no show list and so exports everything its library declares.
Set<String>? shownNames(String source) {
  final Set<String> names = <String>{};
  for (final Match export in RegExp(
    r'^export\b[^;]*;',
    multiLine: true,
  ).allMatches(source)) {
    final Match? show = RegExp(r'\bshow\b([^;]*);').firstMatch(export[0]!);
    if (show == null) {
      return null;
    }
    names.addAll(show[1]!.split(',').map((String name) => name.trim()));
  }
  return names;
}

Set<String>? shownBy(String library) => shownNames(
  File('${packageDirectory().path}/lib/$library').readAsStringSync(),
);

void main() {
  test('the main library exports exactly the declarations topic-model@v1, '
      'topology-dsl@v2 and topology-ir@v1 place in it', () {
    expect(shownBy('nidana_dart_contracts.dart'), <String>{
      // topic-model@v1
      'BusObserver', 'Dedup', 'EventTopic', 'ExecutorSource', 'Lineage',
      'LogLevel', 'MessageEnvelope', 'MessageSource', 'MultiWriterTopic',
      'ObserveContext', 'ObserverCapability', 'PageSource',
      'RedactedPayload', 'ReplayTopic', 'Scope', 'ServiceSource',
      'SpanHandle', 'StateTopic', 'Topic', 'TopicRef', 'TopicVariant',
      'TopologySource', 'Tracing', 'UnknownSource', 'isWellFormedTopicName',
      // topology-dsl@v2: Topologies, The builder, The handle, Pipeline values
      'PipelineValue', 'RawOperator', 'RetryPolicy', 'TopicStream',
      'Topology', 'TopologyBuilder', 'TopologyRef', 'topology',
      // topology-ir@v1: The IR, Function references
      'CombinatorKind', 'EdgeInput', 'FunctionRef', 'StageInput',
      'TopicInput', 'TopologyDefinition', 'TransformEdge',
    });
  });

  test('G2 topology_plan.dart exports exactly the declarations under '
      "topology-dsl@v2's The plan", () {
    expect(shownBy('topology_plan.dart'), <String>{
      'planOf',
      'TopologyPlan',
      'visitStage',
      'visitSink',
      'StageVisitor',
      'SinkVisitor',
      'PlanSink',
      'WriteSink',
      'ReduceIntoSink',
      'ReadStage',
      'MapStage',
      'FilterStage',
      'CombineStage',
      'WithLatestFromStage',
      'MergeStage',
      'SwitchMapStage',
      'ScanStage',
      'PairwiseStage',
      'DistinctUntilChangedStage',
      'DebounceStage',
      'ThrottleStage',
      'DelayStage',
      'SampleStage',
      'BufferStage',
      'TimeoutStage',
      'CatchErrorStage',
      'RawEngineStage',
    });
  });

  test('topology_ir.dart exports exactly the declarations under '
      "topology-ir@v1's Graphs, Renderers, The JSON form and Analyses", () {
    expect(shownBy('topology_ir.dart'), <String>{
      // Graphs
      'ShellClaim', 'TopologyGraph', 'TopologyDefinitionGraph',
      // Renderers
      'GraphRenderer', 'MermaidRenderer', 'GraphvizRenderer', 'JsonRenderer',
      // The JSON form
      'encodeTopologyGraph', 'decodeTopologyGraph',
      'encodeTopologyDefinition', 'decodeTopologyDefinition',
      // Analyses
      'TopologyFinding', 'TopologyCycle', 'SelfReference', 'WriterConflict',
      'ScopeViolation', 'findTopologyCycles', 'findSelfReferences',
      'findWriterConflicts', 'findScopeViolations', 'analyzeTopologyGraph',
      'TopicDeclaration', 'TopicNameCollision', 'findTopicNameCollisions',
    });
  });

  test('the export reader sees show lists and exports without one', () {
    expect(
      shownNames(
        "library;\n\nexport 'a.dart' show A, b;\nexport 'c.dart'\n"
        '    show\n        C,\n        D;\n',
      ),
      <String>{'A', 'b', 'C', 'D'},
    );
    expect(shownNames("export 'a.dart' show A;\nexport 'b.dart';\n"), isNull);
    expect(shownNames("export 'a.dart' hide A;\n"), isNull);
  });
}
