"""The plan's edits to files that exist at HEAD, applied in a copy of the tree.

Usage: python3 -I edits.py <package dir> <set>, where <set> is t1, t2, t4 or
a seeded defect d1 to d8. Every old text must occur exactly once. New files
are copied from draft/ by run.sh; these are the edits to committed files.
"""
import pathlib
import sys

EDITS = {
    # Task 1: the definition body, the import it needs, the recursive
    # boundary test.
    "t1": [
        (
            "lib/src/topology/topology.dart",
            "import '../ir/definition.dart';\n",
            "import '../ir/definition.dart';\nimport '../ir/projection.dart';\n",
        ),
        (
            "lib/src/topology/plan.dart",
            "TopologyDefinition get definition => throw UnimplementedError();",
            "TopologyDefinition get definition => projectPlan(this);",
        ),
        (
            "test/canonical_order_test.dart",
            "for (final FileSystemEntity f in ir.listSync())",
            "for (final FileSystemEntity f in ir.listSync(recursive: true))",
        ),
    ],
    # Task 2: the dartdoc of the helper ShellClaim's equality now shares.
    "t2": [
        (
            "lib/src/topic/list_equality.dart",
            """/// The element-wise comparison of parent correlation ids that envelope and
/// lineage equality use (G13): true when [a] and [b] have the same length and
/// `a[i] == b[i]` at every index. A `List`'s own `==` is identity.""",
            """/// The element-wise comparison that value equality uses for the lists a
/// value holds: an envelope's and a lineage's parent correlation ids
/// (topic-model@v1 G13), and the lists and sets of the IR values, findings,
/// claims and graphs (topology-ir@v1 G7), a set compared as its list: true
/// when [a] and [b] have the same length and `a[i] == b[i]` at every index.
/// A `List`'s own `==` is identity.""",
        ),
    ],
    # Task 4: the messages.
    "t4": [
        (
            "lib/src/topology/builder.dart",
            """        'applies to a state topic read only, and ${topic.name} is an '
            '${topic.variant.name} topic',""",
            """        'applies to a state topic read only, and ${topic.name} is '
        '${_variantOf(topic)}',""",
        ),
        (
            "lib/src/topology/builder.dart",
            """  // Throws ArgumentError unless this builder made every one of [handles]
  // (G14); returns them as an unmodifiable copy.
  List<H> _checkMade<H extends TopicStream<Object?>>(List<H> handles) {
    for (final H handle in handles) {
      if (!identical(handle._builder, this)) {
        throw ArgumentError.value(
          handle,
          'handle',""",
            """  // Throws ArgumentError unless this builder made every one of [handles]
  // (G14), naming the first foreign one by its parameter, the element of
  // [names] at its index; returns [handles] as an unmodifiable copy.
  List<H> _checkMade<H extends TopicStream<Object?>>(
    List<H> handles,
    List<String> names,
  ) {
    for (int i = 0; i < handles.length; i++) {
      if (!identical(handles[i]._builder, this)) {
        throw ArgumentError.value(
          handles[i],
          names[i],""",
        ),
        (
            "lib/src/topology/builder.dart",
            """    _checkMade(<TopicStream<Object?>>[stream]);""",
            """    _checkMade(<TopicStream<Object?>>[stream], const <String>['stream']);""",
        ),
        (
            "lib/src/topology/builder.dart",
            """    _checkMade(<TopicStream<Object?>>[events]);""",
            """    _checkMade(<TopicStream<Object?>>[events], const <String>['events']);""",
        ),
        (
            "lib/src/topology/builder.dart",
            """    final List<TopicStream<Object?>> inputs = _checkMade(<TopicStream<Object?>>[
      a,
      b,
    ]);""",
            """    final List<TopicStream<Object?>> inputs = _checkMade(
      <TopicStream<Object?>>[a, b],
      const <String>['a', 'b'],
    );""",
        ),
        (
            "lib/src/topology/builder.dart",
            """    final List<TopicStream<Object?>> inputs = _checkMade(<TopicStream<Object?>>[
      a,
      b,
      c,
    ]);""",
            """    final List<TopicStream<Object?>> inputs = _checkMade(
      <TopicStream<Object?>>[a, b, c],
      const <String>['a', 'b', 'c'],
    );""",
        ),
        (
            "lib/src/topology/builder.dart",
            """    final List<TopicStream<Object?>> inputs = _checkMade(<TopicStream<Object?>>[
      a,
      b,
      c,
      d,
    ]);""",
            """    final List<TopicStream<Object?>> inputs = _checkMade(
      <TopicStream<Object?>>[a, b, c, d],
      const <String>['a', 'b', 'c', 'd'],
    );""",
        ),
        (
            "lib/src/topology/builder.dart",
            """    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(inputs);
    return _addStage(
      CombineStage<R>._(""",
            """    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(
      inputs,
      _elementNames('inputs', inputs.length),
    );
    return _addStage(
      CombineStage<R>._(""",
        ),
        (
            "lib/src/topology/builder.dart",
            """    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(inputs);
    return _addStage(MergeStage<T>._(this, made), made);""",
            """    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(
      inputs,
      _elementNames('inputs', inputs.length),
    );
    return _addStage(MergeStage<T>._(this, made), made);""",
        ),
        (
            "lib/src/topology/builder.dart",
            """  // Throws ArgumentError for an empty input list (G14).
  void _checkNotEmpty(List<TopicStream<Object?>> inputs) {
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
  }
}
""",
            """  // Throws ArgumentError for an empty input list (G14).
  void _checkNotEmpty(List<TopicStream<Object?>> inputs) {
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
  }
}

// The names of the elements of the list parameter [name], by index:
// 'inputs[0]', 'inputs[1]' and so on.
List<String> _elementNames(String name, int length) => <String>[
  for (int i = 0; i < length; i++) '$name[$i]',
];

// [topic]'s variant with its article, for a message.
String _variantOf(MultiWriterTopic<Object?> topic) => switch (topic) {
  EventTopic<Object?>() => 'an event topic',
  ReplayTopic<Object?>() => 'a replay topic',
};
""",
        ),
        (
            "lib/src/topology/handle.dart",
            """    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[latest],
    );""",
            """    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[latest],
      const <String>['latest'],
    );""",
        ),
        (
            "lib/src/topology/handle.dart",
            """    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[b, c],
    );""",
            """    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[b, c],
      const <String>['b', 'c'],
    );""",
        ),
        (
            "lib/src/topology/handle.dart",
            """    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[b, c, d],
    );""",
            """    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[b, c, d],
      const <String>['b', 'c', 'd'],
    );""",
        ),
        (
            "lib/src/ir/definition.dart",
            """      throw ArgumentError.value(
        inputs.length,
        'inputs',
        'a ${combinator.name} edge takes $count inputs',
      );""",
            """      final String noun = (rule.maxInputs ?? rule.minInputs) == 1
          ? 'input'
          : 'inputs';
      throw ArgumentError.value(
        inputs.length,
        'inputs',
        'a ${combinator.name} edge takes $count $noun',
      );""",
        ),
        (
            "lib/src/ir/definition.dart",
            """          'edge $i is a second sink edge on a state topic',""",
            """          'edge $i is a second sink edge on this state topic, of type '
              '${output.typeName}; two state topics of one name whose value '
              'types render alike, one class name in two libraries, are one '
              'topic in the IR',""",
        ),
    ],
    # Seeded defects, each applied to the finished tree and restored after.
    # d1: the projection names apply, a closure over the combiner.
    "d1": [
        (
            "lib/src/ir/projection.dart",
            """    <EdgeInput>[for (final TopicStream<Object?> i in stage.inputs) _input(i)],
    transformer: FunctionRef.of(stage.combiner),""",
            """    <EdgeInput>[for (final TopicStream<Object?> i in stage.inputs) _input(i)],
    transformer: FunctionRef.of(stage.apply),""",
        ),
    ],
    # d2: a claim keeps a view of the caller's set, not a copy.
    "d2": [
        (
            "lib/src/graph/graph.dart",
            "writes: Set<TopicRef>.unmodifiable(sortedCopy(writes, compareTopicRefs)),",
            "writes: UnmodifiableSetView<TopicRef>(writes),",
        ),
        (
            "lib/src/graph/graph.dart",
            "import 'package:meta/meta.dart';\n",
            "import 'dart:collection';\n\nimport 'package:meta/meta.dart';\n",
        ),
    ],
    # d3: a claim hashes its writes by identity.
    "d3": [
        (
            "lib/src/graph/graph.dart",
            "int get hashCode => Object.hash(source, scope, Object.hashAll(writes));",
            "int get hashCode => Object.hash(source, scope, writes);",
        ),
    ],
    # d4: claims sort by source and scope only, keeping the given order of
    # claims that tie.
    "d4": [
        (
            "lib/src/graph/graph.dart",
            "(ShellClaim a, ShellClaim b) => compareClaimKeys(a._key, b._key),",
            "(ShellClaim a, ShellClaim b) => compareClaimKeys((source: a.source, scope: a.scope, writes: const <TopicRef>[]), (source: b.source, scope: b.scope, writes: const <TopicRef>[])),",
        ),
    ],
    # d5: a graph's equality compares its topologies only.
    "d5": [
        (
            "lib/src/graph/graph.dart",
            """      other is TopologyGraph &&
      elementsEqual(other.topologies, topologies) &&
      elementsEqual(other.claims, claims);""",
            """      other is TopologyGraph && elementsEqual(other.topologies, topologies);""",
        ),
    ],
    # d6: a graph hashes its lists by identity.
    "d6": [
        (
            "lib/src/graph/graph.dart",
            "Object.hash(Object.hashAll(topologies), Object.hashAll(claims));",
            "Object.hash(topologies, claims);",
        ),
    ],
    # d7: a claim's writes keep the order they were given in.
    "d7": [
        (
            "lib/src/graph/graph.dart",
            "writes: Set<TopicRef>.unmodifiable(sortedCopy(writes, compareTopicRefs)),",
            "writes: Set<TopicRef>.unmodifiable(writes),",
        ),
    ],
    # d8: the graph reads its topologies argument twice (once to sort, once
    # more for a length check).
    "d8": [
        (
            "lib/src/graph/graph.dart",
            "    final List<TopologyDefinition> byId = _distinctById(topologies);",
            "    final List<TopologyDefinition> byId = _distinctById(topologies);\n    if (topologies.length < byId.length) throw StateError('lost');",
        ),
    ],
}


def main() -> None:
    package, name = pathlib.Path(sys.argv[1]), sys.argv[2]
    for relative, old, new in EDITS[name]:
        path = package / relative
        text = path.read_text()
        count = text.count(old)
        if count != 1:
            sys.exit(f"{name}: {relative}: old text found {count} times")
        path.write_text(text.replace(old, new))
    print(f"applied {name}: {len(EDITS[name])} edits")


main()
