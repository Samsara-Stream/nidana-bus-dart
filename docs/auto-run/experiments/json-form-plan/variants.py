"""Derive each task's lib/src/json/codec.dart from the final draft.

usage: python3 -I variants.py <draft codec.dart> <draft json_support.dart> <out dir>
writes <out dir>/codec.t1.dart (Task 1: the encoder and JsonRenderer, the
decoders still stubs), <out dir>/codec.t2.dart (Task 2: the decoder reads
every document of the right shape; Task 3's rules are absent) and
<out dir>/json_support.t1.dart (Task 1's part of test/src/json_support.dart:
the fixture readers and the Interface's example). The final drafts are
Task 3's codec.dart and Task 2's json_support.dart. Every replacement must
apply exactly once.
"""
import sys

src, support_src, out = sys.argv[1], sys.argv[2], sys.argv[3]
final = open(src).read()
support = open(support_src).read()


def apply(text, pairs, label):
    for old, new in pairs:
        n = text.count(old)
        if n != 1:
            sys.exit(f"{label}: expected one occurrence, found {n}: {old[:70]!r}")
        text = text.replace(old, new)
    return text


# ---------------------------------------------------------------- Task 1
decode_graph_start = final.index("TopologyGraph decodeTopologyGraph(Object? json) {")
decode_graph_end = final.index("\n}\n", decode_graph_start) + 3
t1 = (final[:decode_graph_start]
      + "TopologyGraph decodeTopologyGraph(Object? json) => throw UnimplementedError();\n"
      + final[decode_graph_end:])
t1 = apply(t1, [
    ("TopologyDefinition decodeTopologyDefinition(Object? json) =>\n    _decodeDefinition(json, r'$');",
     "TopologyDefinition decodeTopologyDefinition(Object? json) =>\n    throw UnimplementedError();"),
    ("import '../topic/message_source.dart';\nimport '../topic/scope.dart';\n", ""),
], "t1")
t1 = t1[: t1.index("// ------------------------------------------------------------ decoding")].rstrip() + "\n"
open(f"{out}/codec.t1.dart", "w").write(t1)

# ---------------------------------------------------------------- Task 2
t2 = apply(final, [
    ("  _checkDistinctIds(topologies, '$path.topologies');\n", ""),
    ("  return _build(\n    path,\n    () => TopologyGraph(topologies: topologies, claims: claims),\n  );\n",
     "  return TopologyGraph(topologies: topologies, claims: claims);\n"),
    ("""// The definition object at [path]: the definition rules (through
// TopologyDefinition), then reads and writes equal to the topics its edges
// read and its sink edges write, each listed once.
""", """// The definition object at [path]. Its reads and writes are read for their
// shape only.
"""),
    ("  final List<TopicRef> reads = _decodeTopics(object['reads'], '$path.reads');\n"
     "  final List<TopicRef> writes = _decodeTopics(object['writes'], '$path.writes');\n",
     "  _decodeTopics(object['reads'], '$path.reads');\n"
     "  _decodeTopics(object['writes'], '$path.writes');\n"),
    ("""  final TopologyDefinition definition = _build(
    path,
    () => TopologyDefinition(
      topologyId: topologyId,
      scope: scope,
      transforms: transforms,
    ),
  );
  _checkSameTopics(reads, definition.reads, '$path.reads', 'the edges read');
  _checkSameTopics(
    writes,
    definition.writes,
    '$path.writes',
    'the sink edges write',
  );
  return definition;
""", """  return TopologyDefinition(
    topologyId: topologyId,
    scope: scope,
    transforms: transforms,
  );
"""),
    ("    return _build(path, () => TransformEdge.write(output, input));\n",
     "    return TransformEdge.write(output, input);\n"),
    ("    return _build(\n      path,\n      () => TransformEdge.reduceInto(output, events, reducer),\n    );\n",
     "    return TransformEdge.reduceInto(output, events, reducer);\n"),
    ("""  return _build(
    path,
    () => TransformEdge.stage(
      combinator,
      inputs,
      transformer: transformer,
      duration: duration,
      retry: retry,
    ),
  );
""", """  return TransformEdge.stage(
    combinator,
    inputs,
    transformer: transformer,
    duration: duration,
    retry: retry,
  );
"""),
    ("""// The input object at [path]: {"edge": n}, or {"topic": ...} with a dedup
// only on a read of a state topic. The index is checked before StageInput
// asserts it.
""", """// The input object at [path]: {"edge": n}, or {"topic": ...} with or
// without a dedup.
"""),
    ("""  final Dedup dedup = _named(Dedup.values, read['dedup'], '$path.dedup');
  if (topic.variant != TopicVariant.state) {
    _reject('$path.dedup', 'may be given only on a read of a state topic');
  }
  return TopicInput(topic, dedup: dedup);
""", """  return TopicInput(
    topic,
    dedup: _named(Dedup.values, read['dedup'], '$path.dedup'),
  );
"""),
    ("// The topic reference object at [path], its typeName not empty.\n",
     "// The topic reference object at [path].\n"),
    ("""  final String typeName = _string(topic['typeName'], '$path.typeName');
  if (typeName.isEmpty) {
    _reject('$path.typeName', 'must not be empty');
  }
  return TopicRef(name: name, variant: variant, typeName: typeName);
""", """  final String typeName = _string(topic['typeName'], '$path.typeName');
  return TopicRef(name: name, variant: variant, typeName: typeName);
"""),
    ("""// The array of topic references at [path], none repeated.
List<TopicRef> _decodeTopics(Object? json, String path) {
  final List<TopicRef> topics = _list(json, path, _decodeTopic);
  final Map<TopicRef, int> first = <TopicRef, int>{};
  for (int i = 0; i < topics.length; i++) {
    final int seen = first.putIfAbsent(topics[i], () => i);
    if (seen != i) {
      _reject('$path[$i]', 'repeats $path[$seen]');
    }
  }
  return topics;
}
""", """// The array of topic references at [path].
List<TopicRef> _decodeTopics(Object? json, String path) =>
    _list(json, path, _decodeTopic);
"""),
    ("""// The function reference object at [path]: a non-empty name, or null.
""", """// The function reference object at [path]: a name, or null.
"""),
    ("    final String name when name.isNotEmpty => FunctionRef.named(name),\n    _ => _reject('$path.name', 'must be a non-empty string or null'),\n",
     "    final String name => FunctionRef.named(name),\n    _ => _reject('$path.name', 'must be a string or null'),\n"),
    ("""// The claim object at [path]: a service, page or executor source rendering,
// a scope, and its state topics, none repeated (through ShellClaim).
""", """// The claim object at [path]: a source rendering, a scope and its topics.
"""),
    ("""  final MessageSource source = switch (MessageSource.tryParse(
    _string(claim['source'], '$path.source'),
  )) {
    final MessageSource s &&
        (ServiceSource() || PageSource() || ExecutorSource()) =>
      s,
    _ => _reject(
      '$path.source',
      'must be "service:", "page:" or "executor:" followed by a name',
    ),
  };
""", """  final MessageSource source =
      MessageSource.tryParse(_string(claim['source'], '$path.source')) ??
      _reject(
        '$path.source',
        'must be "service:", "page:" or "executor:" followed by a name',
      );
"""),
    ("  return _build(\n    path,\n    () => ShellClaim(source: source, scope: scope, writes: writes.toSet()),\n  );\n",
     "  return ShellClaim(source: source, scope: scope, writes: writes.toSet());\n"),
    ("""// [json] as a non-negative integer, the schema's only integers: an int, or a
// double with no fraction below 2^63, which JSON Schema also counts as an
// integer.
int _integer(Object? json, String path) => switch (json) {
  final int n when n >= 0 => n,
  final double d when d >= 0 && d < _twoTo63 && d == d.truncateToDouble() =>
    d.toInt(),
  _ => _reject(path, 'must be a non-negative integer'),
};
""", """// [json] as an integer: an int, or a double with no fraction whose
// magnitude is below 2^63, which JSON Schema also counts as an integer.
int _integer(Object? json, String path) => switch (json) {
  final int n => n,
  final double d when d.abs() < _twoTo63 && d == d.truncateToDouble() =>
    d.toInt(),
  _ => _reject(path, 'must be an integer'),
};
"""),
], "t2")
# drop the two checks and _build, which Task 3 adds
for start_marker, end_marker in [
    ("// Throws unless the topology ids of [topologies]", "// [json] as a JSON object at [path]"),
    ("// What [build] returns:", "// Throws the FormatException that says"),
]:
    a = t2.index(start_marker)
    b = t2.index(end_marker)
    t2 = t2[:a] + t2[b:]
open(f"{out}/codec.t2.dart", "w").write(t2)
# ---------------------------------------------------------------- support
support_t1 = support[: support.index("// ------------------------------------------------------------ generated")].rstrip() + "\n"
support_t1 = apply(support_t1, [("import 'dart:math';\n", "")], "support t1")
open(f"{out}/json_support.t1.dart", "w").write(support_t1)
print("variants: codec.t1.dart, codec.t2.dart, json_support.t1.dart written")
