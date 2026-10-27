// What the tests of topology-ir@v1's JSON form share: the files under
// hsdd/contract/fixture/topology-ir/, the Interface's example, and graphs
// generated from a seed with dart:math for the property tests (nidana.model.13
// Scope), so that a failure names the seed that reproduces it and the package
// takes no dependency beyond test (ADR-002 item 3).
import 'dart:convert';
import 'dart:io';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

import 'package_files.dart';

/// The text of [relative], a path under hsdd/contract/fixture/topology-ir/.
String fixtureText(String relative) =>
    File('${workspaceRoot().path}/hsdd/contract/fixture/topology-ir/$relative')
        .readAsStringSync();

/// The JSON value of [relative], a path under
/// hsdd/contract/fixture/topology-ir/.
Object? fixtureJson(String relative) => jsonDecode(fixtureText(relative));

/// topology-ir@v1's example graph document (the Interface, The JSON form),
/// laid out compactly as the contract shows it.
const String interfaceExample = '''
{
  "format": "topology-ir@v1",
  "topologies": [
    {
      "topologyId": "search",
      "scope": "page",
      "reads": [{ "name": "search.query", "variant": "state", "typeName": "String" }],
      "writes": [{ "name": "search.results", "variant": "state", "typeName": "Results" }],
      "transforms": [
        {
          "combinator": "debounce",
          "inputs": [{ "topic": { "name": "search.query", "variant": "state", "typeName": "String" }, "dedup": "none" }],
          "durationMicros": 300000
        },
        {
          "combinator": "switchMap",
          "inputs": [{ "edge": 0 }],
          "transformer": { "name": "searchApi" },
          "retry": { "name": null }
        },
        {
          "inputs": [{ "edge": 1 }],
          "output": { "name": "search.results", "variant": "state", "typeName": "Results" }
        }
      ]
    }
  ],
  "claims": [
    {
      "source": "service:search-history",
      "scope": "application",
      "writes": [{ "name": "search.history", "variant": "state", "typeName": "History" }]
    }
  ]
}
''';

/// The graph [interfaceExample] describes, built from IR values.
TopologyGraph interfaceExampleGraph() {
  const TopicRef query = TopicRef(
    name: 'search.query',
    variant: TopicVariant.state,
    typeName: 'String',
  );
  const TopicRef results = TopicRef(
    name: 'search.results',
    variant: TopicVariant.state,
    typeName: 'Results',
  );
  const TopicRef history = TopicRef(
    name: 'search.history',
    variant: TopicVariant.state,
    typeName: 'History',
  );
  return TopologyGraph(
    topologies: <TopologyDefinition>[
      TopologyDefinition(
        topologyId: 'search',
        scope: Scope.page,
        transforms: <TransformEdge>[
          TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[
            const TopicInput(query, dedup: Dedup.none),
          ], duration: const Duration(milliseconds: 300)),
          TransformEdge.stage(
            CombinatorKind.switchMap,
            <EdgeInput>[const StageInput(0)],
            transformer: FunctionRef.named('searchApi'),
            retry: const FunctionRef.anonymous(),
          ),
          TransformEdge.write(results, const StageInput(1)),
        ],
      ),
    ],
    claims: <ShellClaim>[
      ShellClaim(
        source: const ServiceSource('search-history'),
        writes: <TopicRef>{history},
      ),
    ],
  );
}
