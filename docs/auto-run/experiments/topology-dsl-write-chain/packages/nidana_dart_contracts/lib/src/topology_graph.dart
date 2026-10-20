/// Stand-in for the topology-ir@v1 declarations of
/// `package:nidana_dart_contracts/topology_ir.dart`: graphs, shell claims,
/// renderers, the JSON form and the analyses.
///
/// Throwaway experiment code: it implements the Interface of
/// hsdd/contract/topology-ir.md as directly as possible so that the
/// contract's fixtures can be replayed before the real package exists.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import 'topic_model.dart';
import 'topology_ir.dart';

// ------------------------------------------------------------ ordering

int _compareLists<T>(List<T> a, List<T> b, int Function(T, T) compare) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final c = compare(a[i], b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}

List<TopicRef> _canonical(Iterable<TopicRef> refs) =>
    <TopicRef>{...refs}.toList()..sort(compareTopicRefs);

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ------------------------------------------------------------ claims

/// A shell publisher's claim (Spec §2.4, §3.11, §7.2).
@immutable
final class ShellClaim {
  factory ShellClaim({
    required MessageSource source,
    Scope scope = Scope.application,
    required Set<TopicRef> writes,
  }) {
    if (source is TopologySource || source is UnknownSource) {
      throw ArgumentError.value(
          source, 'source', 'must be a service, page or executor source');
    }
    if (writes.isEmpty) {
      throw ArgumentError.value(writes, 'writes', 'must not be empty');
    }
    for (final w in writes) {
      if (w.variant != TopicVariant.state) {
        throw ArgumentError.value(
            writes, 'writes', '${w.name} is not a state topic');
      }
    }
    return ShellClaim._(
        source, scope, Set<TopicRef>.unmodifiable(_canonical(writes)));
  }

  const ShellClaim._(this.source, this.scope, this.writes);

  final MessageSource source;
  final Scope scope;
  final Set<TopicRef> writes;

  @override
  bool operator ==(Object other) =>
      other is ShellClaim &&
      other.source == source &&
      other.scope == scope &&
      _listEquals(other.writes.toList(), writes.toList());

  @override
  int get hashCode => Object.hash(source, scope, Object.hashAll(writes));

  @override
  String toString() => 'ShellClaim($source, ${scope.name}, '
      '${writes.map((w) => w.name).join(', ')})';
}

int _compareClaims(ShellClaim a, ShellClaim b) {
  final bySource = a.source.toString().compareTo(b.source.toString());
  if (bySource != 0) return bySource;
  final byScope = a.scope.index.compareTo(b.scope.index);
  if (byScope != 0) return byScope;
  return _compareLists(a.writes.toList(), b.writes.toList(), compareTopicRefs);
}

// ------------------------------------------------------------ graph

/// Topologies and shell claims (Spec §6.5, Appendix A.4, A.9).
@immutable
final class TopologyGraph {
  factory TopologyGraph({
    Iterable<TopologyDefinition> topologies = const <TopologyDefinition>[],
    Iterable<ShellClaim> claims = const <ShellClaim>[],
  }) {
    final byId = <String, TopologyDefinition>{};
    for (final d in topologies) {
      final seen = byId[d.topologyId];
      if (seen != null && seen != d) {
        throw ArgumentError.value(d, 'topologies',
            'two different definitions share the topologyId "${d.topologyId}"');
      }
      byId[d.topologyId] = d;
    }
    final ordered = byId.values.toList()
      ..sort((a, b) => a.topologyId.compareTo(b.topologyId));
    final claimList = claims.toList()..sort(_compareClaims);
    return TopologyGraph._(
      List<TopologyDefinition>.unmodifiable(ordered),
      List<ShellClaim>.unmodifiable(claimList),
      List<TopicRef>.unmodifiable(_canonical(<TopicRef>[
        for (final d in ordered) ...d.reads,
        for (final d in ordered) ...d.writes,
        for (final c in claimList) ...c.writes,
      ])),
    );
  }

  const TopologyGraph._(this.topologies, this.claims, this.topics);

  final List<TopologyDefinition> topologies;
  final List<ShellClaim> claims;
  final List<TopicRef> topics;

  String render(GraphRenderer renderer) => renderer.render(this);

  @override
  bool operator ==(Object other) =>
      other is TopologyGraph &&
      _listEquals(other.topologies, topologies) &&
      _listEquals(other.claims, claims);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(topologies), Object.hashAll(claims));

  @override
  String toString() => 'TopologyGraph(${topologies.length} topologies, '
      '${claims.length} claims)';
}

extension TopologyDefinitionGraph on TopologyDefinition {
  /// Spec §6.5's `ir.toGraph()`.
  TopologyGraph toGraph() =>
      TopologyGraph(topologies: <TopologyDefinition>[this]);
}

// ------------------------------------------------------------ renderers

abstract interface class GraphRenderer {
  String render(TopologyGraph graph);
}

String _duration(Duration d) {
  final us = d.inMicroseconds;
  if (us % 1000000 == 0) return '${us ~/ 1000000}s';
  if (us % 1000 == 0) return '${us ~/ 1000}ms';
  return '${us}us';
}

String _fn(FunctionRef f) => f.name ?? '(anonymous)';

/// The label lines of an edge, unescaped.
List<String> _edgeLines(TransformEdge e) => <String>[
      (e.combinator?.name ?? 'write') +
          (e.duration == null ? '' : ' ${_duration(e.duration!)}'),
      if (e.transformer case final FunctionRef t) _fn(t),
      if (e.retry case final FunctionRef r) 'retry ${_fn(r)}',
    ];

abstract base class _TextRenderer implements GraphRenderer {
  const _TextRenderer();

  String esc(String text);
  String get lineBreak;
  String header();
  String footer();
  String topicNode(String id, String label);
  String openTopology(String id, String label);
  String closeTopology();
  String edgeNode(String id, String label);
  String claimNode(String id, String label);
  String arrow(String from, String to, String? label);

  String _label(List<String> lines) => lines.map(esc).join(lineBreak);

  @override
  String render(TopologyGraph graph) {
    final out = StringBuffer(header());
    final topicId = <TopicRef, String>{
      for (var i = 0; i < graph.topics.length; i++) graph.topics[i]: 't$i',
    };
    for (final t in graph.topics) {
      out.write(topicNode(topicId[t]!,
          _label(<String>[t.name, '${t.variant.name} ${t.typeName}'])));
    }
    for (var j = 0; j < graph.topologies.length; j++) {
      final d = graph.topologies[j];
      out.write(openTopology('p$j', _label(<String>[d.topologyId, d.scope.name])));
      for (var k = 0; k < d.transforms.length; k++) {
        out.write(edgeNode('p${j}e$k', _label(_edgeLines(d.transforms[k]))));
      }
      out.write(closeTopology());
    }
    for (var m = 0; m < graph.claims.length; m++) {
      final c = graph.claims[m];
      out.write(claimNode(
          's$m', _label(<String>[c.source.toString(), c.scope.name])));
    }
    for (var j = 0; j < graph.topologies.length; j++) {
      final d = graph.topologies[j];
      for (var k = 0; k < d.transforms.length; k++) {
        final e = d.transforms[k];
        for (final input in e.inputs) {
          switch (input) {
            case TopicInput(:final topic, :final dedup):
              out.write(arrow(topicId[topic]!, 'p${j}e$k',
                  dedup == null ? null : 'dedup ${dedup.name}'));
            case StageInput(:final edge):
              out.write(arrow('p${j}e$edge', 'p${j}e$k', null));
          }
        }
        if (e.output case final TopicRef out$) {
          out.write(arrow('p${j}e$k', topicId[out$]!, null));
        }
      }
    }
    for (var m = 0; m < graph.claims.length; m++) {
      for (final w in graph.claims[m].writes) {
        out.write(arrow('s$m', topicId[w]!, null));
      }
    }
    out.write(footer());
    return out.toString();
  }
}

/// Mermaid flowchart text.
final class MermaidRenderer extends _TextRenderer {
  const MermaidRenderer();

  @override
  String esc(String text) => text
      .replaceAll('#', '#35;')
      .replaceAll('"', '#quot;')
      .replaceAll('<', '#lt;')
      .replaceAll('>', '#gt;')
      .replaceAll('\n', '#10;');
  @override
  String get lineBreak => '<br/>';
  @override
  String header() => 'flowchart LR\n';
  @override
  String footer() => '';
  @override
  String topicNode(String id, String label) => '  $id(["$label"])\n';
  @override
  String openTopology(String id, String label) => '  subgraph $id["$label"]\n';
  @override
  String closeTopology() => '  end\n';
  @override
  String edgeNode(String id, String label) => '    $id["$label"]\n';
  @override
  String claimNode(String id, String label) => '  $id["$label"]\n';
  @override
  String arrow(String from, String to, String? label) =>
      label == null ? '  $from --> $to\n' : '  $from -->|$label| $to\n';
}

/// Graphviz DOT text.
final class GraphvizRenderer extends _TextRenderer {
  const GraphvizRenderer();

  @override
  String esc(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
  @override
  String get lineBreak => r'\n';
  @override
  String header() => 'digraph topologies {\n  rankdir=LR;\n';
  @override
  String footer() => '}\n';
  @override
  String topicNode(String id, String label) =>
      '  $id [shape=ellipse, label="$label"];\n';
  @override
  String openTopology(String id, String label) =>
      '  subgraph cluster_$id {\n    label="$label";\n';
  @override
  String closeTopology() => '  }\n';
  @override
  String edgeNode(String id, String label) =>
      '    $id [shape=box, label="$label"];\n';
  @override
  String claimNode(String id, String label) =>
      '  $id [shape=box, style=rounded, label="$label"];\n';
  @override
  String arrow(String from, String to, String? label) => label == null
      ? '  $from -> $to;\n'
      : '  $from -> $to [label="$label"];\n';
}

/// The graph document as JSON text.
final class JsonRenderer implements GraphRenderer {
  const JsonRenderer();

  @override
  String render(TopologyGraph graph) =>
      '${const JsonEncoder.withIndent('  ').convert(encodeTopologyGraph(graph))}\n';
}

// ------------------------------------------------------------ JSON

const String _format = 'topology-ir@v1';

Map<String, Object?> _ref(TopicRef r) => <String, Object?>{
      'name': r.name,
      'variant': r.variant.name,
      'typeName': r.typeName,
    };

Map<String, Object?> _functionRef(FunctionRef f) =>
    <String, Object?>{'name': f.name};

Map<String, Object?> _input(EdgeInput i) => switch (i) {
      TopicInput(:final topic, :final dedup) => <String, Object?>{
          'topic': _ref(topic),
          if (dedup != null) 'dedup': dedup.name,
        },
      StageInput(:final edge) => <String, Object?>{'edge': edge},
    };

Map<String, Object?> _edge(TransformEdge e) => <String, Object?>{
      if (e.combinator != null) 'combinator': e.combinator!.name,
      'inputs': <Object?>[for (final i in e.inputs) _input(i)],
      if (e.output != null) 'output': _ref(e.output!),
      if (e.transformer != null) 'transformer': _functionRef(e.transformer!),
      if (e.duration != null) 'durationMicros': e.duration!.inMicroseconds,
      if (e.retry != null) 'retry': _functionRef(e.retry!),
    };

Map<String, Object?> encodeTopologyDefinition(TopologyDefinition d) =>
    <String, Object?>{
      'topologyId': d.topologyId,
      'scope': d.scope.name,
      'reads': <Object?>[for (final r in d.reads) _ref(r)],
      'writes': <Object?>[for (final w in d.writes) _ref(w)],
      'transforms': <Object?>[for (final e in d.transforms) _edge(e)],
    };

Map<String, Object?> encodeTopologyGraph(TopologyGraph g) => <String, Object?>{
      'format': _format,
      'topologies': <Object?>[
        for (final d in g.topologies) encodeTopologyDefinition(d),
      ],
      'claims': <Object?>[
        for (final c in g.claims)
          <String, Object?>{
            'source': c.source.toString(),
            'scope': c.scope.name,
            'writes': <Object?>[for (final w in c.writes) _ref(w)],
          },
      ],
    };

final class _Reader {
  _Reader(this.path);
  final String path;

  Never fail(String why) => throw FormatException('$path: $why');

  Map<String, Object?> object(Object? json, Set<String> required,
      [Set<String> optional = const <String>{}]) {
    if (json is! Map<String, Object?>) fail('expected an object');
    for (final k in required) {
      if (!json.containsKey(k)) fail('missing "$k"');
    }
    for (final k in json.keys) {
      if (!required.contains(k) && !optional.contains(k)) {
        fail('unexpected "$k"');
      }
    }
    return json;
  }

  _Reader at(Object key) => _Reader('$path/$key');

  String string(Object? json) => json is String ? json : fail('expected a string');

  int integer(Object? json) => json is int ? json : fail('expected an integer');

  List<Object?> list(Object? json) =>
      json is List<Object?> ? json : fail('expected an array');

  T enumValue<T extends Enum>(Object? json, List<T> values) {
    final s = string(json);
    for (final v in values) {
      if (v.name == s) return v;
    }
    return fail('unknown value "$s"');
  }
}

TopicRef _readRef(_Reader r, Object? json) {
  final m = r.object(json, const <String>{'name', 'variant', 'typeName'});
  return TopicRef(
    name: r.at('name').string(m['name']),
    variant: r.at('variant').enumValue(m['variant'], TopicVariant.values),
    typeName: r.at('typeName').string(m['typeName']),
  );
}

FunctionRef _readFunctionRef(_Reader r, Object? json) {
  final m = r.object(json, const <String>{'name'});
  final name = m['name'];
  if (name == null) return const FunctionRef.anonymous();
  final s = r.at('name').string(name);
  if (s.isEmpty) r.at('name').fail('must not be empty');
  return FunctionRef.named(s);
}

EdgeInput _readInput(_Reader r, Object? json) {
  if (json is Map<String, Object?> && json.containsKey('edge')) {
    final m = r.object(json, const <String>{'edge'});
    final edge = r.at('edge').integer(m['edge']);
    if (edge < 0) r.at('edge').fail('must not be negative');
    return StageInput(edge);
  }
  final m = r.object(json, const <String>{'topic'}, const <String>{'dedup'});
  final topic = _readRef(r.at('topic'), m['topic']);
  final dedup = m.containsKey('dedup')
      ? r.at('dedup').enumValue(m['dedup'], Dedup.values)
      : null;
  if (dedup != null && topic.variant != TopicVariant.state) {
    r.at('dedup').fail('applies to a state topic read only');
  }
  return TopicInput(topic, dedup: dedup);
}

TransformEdge _readEdge(_Reader r, Object? json) {
  final m = r.object(json, const <String>{'inputs'}, const <String>{
    'combinator',
    'output',
    'transformer',
    'durationMicros',
    'retry',
  });
  final inputs = <EdgeInput>[
    for (final (i, x) in r.at('inputs').list(m['inputs']).indexed)
      _readInput(r.at('inputs').at(i), x),
  ];
  final output =
      m.containsKey('output') ? _readRef(r.at('output'), m['output']) : null;
  final transformer = m.containsKey('transformer')
      ? _readFunctionRef(r.at('transformer'), m['transformer'])
      : null;
  final retry =
      m.containsKey('retry') ? _readFunctionRef(r.at('retry'), m['retry']) : null;
  Duration? duration;
  if (m.containsKey('durationMicros')) {
    final us = r.at('durationMicros').integer(m['durationMicros']);
    if (us < 0) r.at('durationMicros').fail('must not be negative');
    duration = Duration(microseconds: us);
  }
  try {
    if (!m.containsKey('combinator')) {
      if (inputs.length != 1 ||
          output == null ||
          transformer != null ||
          duration != null ||
          retry != null) {
        r.fail('a write has exactly one input, an output and nothing else');
      }
      return TransformEdge.write(output, inputs.single);
    }
    final kind = r.at('combinator').enumValue(m['combinator'], CombinatorKind.values);
    if (kind == CombinatorKind.reduceInto) {
      if (inputs.length != 1 ||
          output == null ||
          transformer == null ||
          duration != null ||
          retry != null) {
        r.fail('a reduceInto has exactly one input, an output and a transformer');
      }
      return TransformEdge.reduceInto(output, inputs.single, transformer);
    }
    if (output != null) r.at('output').fail('a stage has no output');
    return TransformEdge.stage(kind, inputs,
        transformer: transformer, duration: duration, retry: retry);
  } on ArgumentError catch (e) {
    r.fail('${e.message}');
  }
}

TopologyDefinition _readDefinition(_Reader r, Object? json) {
  final m = r.object(json, const <String>{
    'topologyId',
    'scope',
    'reads',
    'writes',
    'transforms',
  });
  final id = r.at('topologyId').string(m['topologyId']);
  final scope = r.at('scope').enumValue(m['scope'], Scope.values);
  final reads = <TopicRef>[
    for (final (i, x) in r.at('reads').list(m['reads']).indexed)
      _readRef(r.at('reads').at(i), x),
  ];
  final writes = <TopicRef>[
    for (final (i, x) in r.at('writes').list(m['writes']).indexed)
      _readRef(r.at('writes').at(i), x),
  ];
  final transforms = <TransformEdge>[
    for (final (i, x) in r.at('transforms').list(m['transforms']).indexed)
      _readEdge(r.at('transforms').at(i), x),
  ];
  final TopologyDefinition d;
  try {
    d = TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);
  } on ArgumentError catch (e) {
    r.fail('${e.message}');
  }
  if (reads.toSet().length != reads.length ||
      reads.length != d.reads.length ||
      !d.reads.containsAll(reads)) {
    r.at('reads').fail('must list the topics the edges read, each once');
  }
  if (writes.toSet().length != writes.length ||
      writes.length != d.writes.length ||
      !d.writes.containsAll(writes)) {
    r.at('writes').fail('must list the topics the sink edges write, each once');
  }
  return d;
}

TopologyDefinition decodeTopologyDefinition(Object? json) =>
    _readDefinition(_Reader(''), json);

TopologyGraph decodeTopologyGraph(Object? json) {
  final r = _Reader('');
  final m = r.object(json, const <String>{'format', 'topologies', 'claims'});
  if (m['format'] != _format) {
    r.at('format').fail('expected "$_format"');
  }
  final topologies = <TopologyDefinition>[
    for (final (i, x) in r.at('topologies').list(m['topologies']).indexed)
      _readDefinition(r.at('topologies').at(i), x),
  ];
  final ids = <String>{};
  for (final (i, d) in topologies.indexed) {
    if (!ids.add(d.topologyId)) {
      r.at('topologies').at(i).fail('repeats the topologyId "${d.topologyId}"');
    }
  }
  final claims = <ShellClaim>[];
  for (final (i, x) in r.at('claims').list(m['claims']).indexed) {
    final c = r.at('claims').at(i);
    final cm = c.object(x, const <String>{'source', 'scope', 'writes'});
    final source = MessageSource.tryParse(c.at('source').string(cm['source']));
    if (source == null) c.at('source').fail('is not a source rendering');
    final writes = <TopicRef>[
      for (final (k, w) in c.at('writes').list(cm['writes']).indexed)
        _readRef(c.at('writes').at(k), w),
    ];
    if (writes.toSet().length != writes.length) {
      c.at('writes').fail('repeats a topic');
    }
    try {
      claims.add(ShellClaim(
        source: source,
        scope: c.at('scope').enumValue(cm['scope'], Scope.values),
        writes: writes.toSet(),
      ));
    } on ArgumentError catch (e) {
      c.fail('${e.message}');
    }
  }
  return TopologyGraph(topologies: topologies, claims: claims);
}

// ------------------------------------------------------------ analyses

@immutable
sealed class TopologyFinding {
  const TopologyFinding._();
}

final class TopologyCycle extends TopologyFinding {
  TopologyCycle({required List<String> topologyIds, required List<TopicRef> topics})
      : topologyIds = List<String>.unmodifiable(topologyIds),
        topics = List<TopicRef>.unmodifiable(topics),
        super._();
  final List<String> topologyIds;
  final List<TopicRef> topics;

  @override
  bool operator ==(Object other) =>
      other is TopologyCycle &&
      _listEquals(other.topologyIds, topologyIds) &&
      _listEquals(other.topics, topics);
  @override
  int get hashCode => Object.hash(
      TopologyCycle, Object.hashAll(topologyIds), Object.hashAll(topics));
  @override
  String toString() => 'TopologyCycle($topologyIds via ${topics.map((t) => t.name)})';
}

final class SelfReference extends TopologyFinding {
  SelfReference({
    required this.topologyId,
    required this.topic,
    required List<int> edges,
  })  : edges = List<int>.unmodifiable(edges),
        super._();
  final String topologyId;
  final TopicRef topic;
  final List<int> edges;

  @override
  bool operator ==(Object other) =>
      other is SelfReference &&
      other.topologyId == topologyId &&
      other.topic == topic &&
      _listEquals(other.edges, edges);
  @override
  int get hashCode =>
      Object.hash(SelfReference, topologyId, topic, Object.hashAll(edges));
  @override
  String toString() => 'SelfReference($topologyId, ${topic.name}, $edges)';
}

final class WriterConflict extends TopologyFinding {
  WriterConflict({required this.topic, required List<MessageSource> writers})
      : writers = List<MessageSource>.unmodifiable(writers),
        super._();
  final TopicRef topic;
  final List<MessageSource> writers;

  @override
  bool operator ==(Object other) =>
      other is WriterConflict &&
      other.topic == topic &&
      _listEquals(other.writers, writers);
  @override
  int get hashCode => Object.hash(WriterConflict, topic, Object.hashAll(writers));
  @override
  String toString() => 'WriterConflict(${topic.name}, $writers)';
}

final class ScopeViolation extends TopologyFinding {
  const ScopeViolation({
    required this.topic,
    required this.owner,
    required this.ownerScope,
    required this.readerId,
    required this.readerScope,
  }) : super._();
  final TopicRef topic;
  final MessageSource owner;
  final Scope ownerScope;
  final String readerId;
  final Scope readerScope;

  @override
  bool operator ==(Object other) =>
      other is ScopeViolation &&
      other.topic == topic &&
      other.owner == owner &&
      other.ownerScope == ownerScope &&
      other.readerId == readerId &&
      other.readerScope == readerScope;
  @override
  int get hashCode =>
      Object.hash(ScopeViolation, topic, owner, ownerScope, readerId, readerScope);
  @override
  String toString() => 'ScopeViolation(${topic.name}: $owner ${ownerScope.name} '
      'read by $readerId ${readerScope.name})';
}

List<TopologyCycle> findTopologyCycles(TopologyGraph graph) {
  final nodes = graph.topologies;
  final n = nodes.length;
  final succ = List<List<int>>.generate(n, (_) => <int>[]);
  for (var a = 0; a < n; a++) {
    for (var b = 0; b < n; b++) {
      if (a != b && nodes[a].writes.any(nodes[b].reads.contains)) {
        succ[a].add(b);
      }
    }
  }
  // Tarjan's strongly connected components.
  var counter = 0;
  final index = List<int?>.filled(n, null);
  final low = List<int>.filled(n, 0);
  final onStack = List<bool>.filled(n, false);
  final stack = <int>[];
  final components = <List<int>>[];
  void connect(int v) {
    index[v] = counter;
    low[v] = counter;
    counter++;
    stack.add(v);
    onStack[v] = true;
    for (final w in succ[v]) {
      if (index[w] == null) {
        connect(w);
        low[v] = low[v] < low[w] ? low[v] : low[w];
      } else if (onStack[w]) {
        low[v] = low[v] < index[w]! ? low[v] : index[w]!;
      }
    }
    if (low[v] == index[v]) {
      final c = <int>[];
      int w;
      do {
        w = stack.removeLast();
        onStack[w] = false;
        c.add(w);
      } while (w != v);
      components.add(c);
    }
  }

  for (var v = 0; v < n; v++) {
    if (index[v] == null) connect(v);
  }
  final cycles = <TopologyCycle>[
    for (final c in components)
      if (c.length > 1)
        TopologyCycle(
          topologyIds: (c.map((i) => nodes[i].topologyId).toList()..sort()),
          topics: _canonical(<TopicRef>[
            for (final a in c)
              for (final b in c)
                if (a != b)
                  ...nodes[a].writes.where(nodes[b].reads.contains),
          ]),
        ),
  ]..sort((x, y) => x.topologyIds.first.compareTo(y.topologyIds.first));
  return List<TopologyCycle>.unmodifiable(cycles);
}

List<SelfReference> findSelfReferences(TopologyDefinition d) {
  final edges = d.transforms;
  final found = <SelfReference>[];
  for (final x in _canonical(d.reads.where(d.writes.contains))) {
    final forward = <int>{};
    for (var k = 0; k < edges.length; k++) {
      final e = edges[k];
      if (e.isStateBearing) continue;
      if (e.inputs.any((i) =>
          (i is TopicInput && i.topic == x) ||
          (i is StageInput && forward.contains(i.edge)))) {
        forward.add(k);
      }
    }
    final backward = <int>{};
    for (var k = edges.length - 1; k >= 0; k--) {
      final e = edges[k];
      if (e.isStateBearing) continue;
      if (e.output == x) backward.add(k);
      if (backward.contains(k)) {
        for (final i in e.inputs) {
          if (i is StageInput && !edges[i.edge].isStateBearing) {
            backward.add(i.edge);
          }
        }
      }
    }
    final on = forward.intersection(backward).toList()..sort();
    if (on.isNotEmpty) {
      found.add(SelfReference(topologyId: d.topologyId, topic: x, edges: on));
    }
  }
  return List<SelfReference>.unmodifiable(found);
}

typedef _Owner = ({MessageSource source, Scope scope});

Map<TopicRef, List<_Owner>> _owners(TopologyGraph g) {
  final owners = <TopicRef, List<_Owner>>{};
  for (final d in g.topologies) {
    for (final w in d.writes) {
      if (w.variant != TopicVariant.state) continue;
      (owners[w] ??= <_Owner>[])
          .add((source: TopologySource(d.topologyId), scope: d.scope));
    }
  }
  for (final c in g.claims) {
    for (final w in c.writes) {
      (owners[w] ??= <_Owner>[]).add((source: c.source, scope: c.scope));
    }
  }
  return owners;
}

List<WriterConflict> findWriterConflicts(TopologyGraph graph) {
  final owners = _owners(graph);
  return List<WriterConflict>.unmodifiable(<WriterConflict>[
    for (final t in _canonical(owners.keys))
      if (owners[t]!.length > 1)
        WriterConflict(
          topic: t,
          writers: owners[t]!.map((o) => o.source).toList()
            ..sort((a, b) => a.toString().compareTo(b.toString())),
        ),
  ]);
}

List<ScopeViolation> findScopeViolations(TopologyGraph graph) {
  final owners = _owners(graph);
  final found = <ScopeViolation>{};
  for (final t in _canonical(owners.keys)) {
    final sortedOwners = owners[t]!.toList()
      ..sort((a, b) {
        final bySource = a.source.toString().compareTo(b.source.toString());
        return bySource != 0 ? bySource : a.scope.index.compareTo(b.scope.index);
      });
    for (final o in sortedOwners) {
      for (final r in graph.topologies) {
        if (!r.reads.contains(t)) continue;
        if (!o.scope.isAtLeastAsLongAs(r.scope)) {
          found.add(ScopeViolation(
            topic: t,
            owner: o.source,
            ownerScope: o.scope,
            readerId: r.topologyId,
            readerScope: r.scope,
          ));
        }
      }
    }
  }
  return List<ScopeViolation>.unmodifiable(found.toList());
}

List<TopologyFinding> analyzeTopologyGraph(TopologyGraph graph) =>
    List<TopologyFinding>.unmodifiable(<TopologyFinding>[
      ...findTopologyCycles(graph),
      for (final d in graph.topologies) ...findSelfReferences(d),
      ...findWriterConflicts(graph),
      ...findScopeViolations(graph),
    ]);

// ------------------------------------------------------------ names

@immutable
final class TopicDeclaration {
  const TopicDeclaration({required this.topic, required this.site});
  final TopicRef topic;
  final String site;

  @override
  bool operator ==(Object other) =>
      other is TopicDeclaration && other.topic == topic && other.site == site;
  @override
  int get hashCode => Object.hash(TopicDeclaration, topic, site);
  @override
  String toString() => 'TopicDeclaration(${topic.name} at $site)';
}

@immutable
final class TopicNameCollision {
  TopicNameCollision({
    required this.name,
    required List<TopicDeclaration> declarations,
  }) : declarations = List<TopicDeclaration>.unmodifiable(declarations);
  final String name;
  final List<TopicDeclaration> declarations;

  @override
  bool operator ==(Object other) =>
      other is TopicNameCollision &&
      other.name == name &&
      _listEquals(other.declarations, declarations);
  @override
  int get hashCode =>
      Object.hash(TopicNameCollision, name, Object.hashAll(declarations));
  @override
  String toString() => 'TopicNameCollision($name, $declarations)';
}

List<TopicNameCollision> findTopicNameCollisions(
    Iterable<TopicDeclaration> declarations) {
  final byName = <String, Set<TopicDeclaration>>{};
  for (final d in declarations) {
    (byName[d.topic.name] ??= <TopicDeclaration>{}).add(d);
  }
  final names = byName.keys.toList()..sort();
  return List<TopicNameCollision>.unmodifiable(<TopicNameCollision>[
    for (final name in names)
      if (byName[name]!.length > 1)
        TopicNameCollision(
          name: name,
          declarations: byName[name]!.toList()
            ..sort((a, b) {
              final bySite = a.site.compareTo(b.site);
              return bySite != 0 ? bySite : compareTopicRefs(a.topic, b.topic);
            }),
        ),
  ]);
}
