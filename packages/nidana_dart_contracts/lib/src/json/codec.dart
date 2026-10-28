import 'dart:convert';

import '../graph/graph.dart';
import '../ir/definition.dart';
import '../ir/function_ref.dart';
import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

/// The graph document of [graph] as a JSON value (maps, lists, strings,
/// integers, booleans and null), keys in the order the schema lists them.
Map<String, Object?> encodeTopologyGraph(TopologyGraph graph) =>
    <String, Object?>{
      'format': _format,
      'topologies': <Object?>[
        for (final TopologyDefinition definition in graph.topologies)
          encodeTopologyDefinition(definition),
      ],
      'claims': <Object?>[
        for (final ShellClaim claim in graph.claims) _encodeClaim(claim),
      ],
    };

/// The graph a graph document describes. Throws FormatException, and no
/// other error, for any value that is not a graph document of this version
/// or breaks a rule of the decoder.
TopologyGraph decodeTopologyGraph(Object? json) {
  final Map<String, Object?> document = _object(json, r'$', const <String>{
    'format',
    'topologies',
    'claims',
  });
  if (document['format'] != _format) {
    _reject(r'$.format', 'must be ${jsonEncode(_format)}');
  }
  final List<TopologyDefinition> topologies = _list(
    document['topologies'],
    r'$.topologies',
    _decodeDefinition,
  );
  _checkDistinctIds(topologies, r'$.topologies');
  final List<ShellClaim> claims = _list(
    document['claims'],
    r'$.claims',
    _decodeClaim,
  );
  return _build(
    r'$',
    () => TopologyGraph(topologies: topologies, claims: claims),
  );
}

/// The object a graph document lists for [definition], and its inverse.
Map<String, Object?> encodeTopologyDefinition(
  TopologyDefinition definition,
) => <String, Object?>{
  'topologyId': definition.topologyId,
  'scope': definition.scope.name,
  'reads': <Object?>[
    for (final TopicRef topic in definition.reads) _encodeTopic(topic),
  ],
  'writes': <Object?>[
    for (final TopicRef topic in definition.writes) _encodeTopic(topic),
  ],
  'transforms': <Object?>[
    for (final TransformEdge edge in definition.transforms) _encodeEdge(edge),
  ],
};
TopologyDefinition decodeTopologyDefinition(Object? json) =>
    _decodeDefinition(json, r'$');

/// The graph document as JSON text (The JSON form).
final class JsonRenderer implements GraphRenderer {
  const JsonRenderer();

  // The graph document of graph as JSON text: its encoding indented by two
  // spaces, a newline at the end.
  @override
  String render(TopologyGraph graph) =>
      '${_indented.convert(encodeTopologyGraph(graph))}\n';
}

// The value of a graph document's "format" member, which the encoder writes
// and the decoder compares a document's "format" with.
const String _format = 'topology-ir@v1';

// The encoder behind JsonRenderer.render: two-space indentation, keys in the
// order of the map it is given.
const JsonEncoder _indented = JsonEncoder.withIndent('  ');

// The object a graph document lists for edge: combinator (not for a write),
// inputs, then output, transformer, durationMicros and retry, each only where
// the edge holds one.
Map<String, Object?> _encodeEdge(TransformEdge edge) => <String, Object?>{
  if (edge.combinator case final CombinatorKind combinator)
    'combinator': combinator.name,
  'inputs': <Object?>[
    for (final EdgeInput input in edge.inputs) _encodeInput(input),
  ],
  if (edge.output case final TopicRef output) 'output': _encodeTopic(output),
  if (edge.transformer case final FunctionRef transformer)
    'transformer': _encodeFunction(transformer),
  if (edge.duration case final Duration duration)
    'durationMicros': duration.inMicroseconds,
  if (edge.retry case final FunctionRef retry) 'retry': _encodeFunction(retry),
};

// The object a graph document lists for input: {topic} with dedup after it
// when the read gave one, or {edge}.
Map<String, Object?> _encodeInput(EdgeInput input) => switch (input) {
  TopicInput(:final TopicRef topic, :final Dedup? dedup) => <String, Object?>{
    'topic': _encodeTopic(topic),
    if (dedup != null) 'dedup': dedup.name,
  },
  StageInput(:final int edge) => <String, Object?>{'edge': edge},
};

// The object a graph document lists for topic: name, variant by name and
// typeName.
Map<String, Object?> _encodeTopic(TopicRef topic) => <String, Object?>{
  'name': topic.name,
  'variant': topic.variant.name,
  'typeName': topic.typeName,
};

// The object a graph document lists for function: its name, null when it is
// anonymous.
Map<String, Object?> _encodeFunction(FunctionRef function) => <String, Object?>{
  'name': function.name,
};

// The object a graph document lists for claim: its source as the source
// renders, its scope by name and its writes in the claim's canonical order.
Map<String, Object?> _encodeClaim(ShellClaim claim) => <String, Object?>{
  'source': claim.source.toString(),
  'scope': claim.scope.name,
  'writes': <Object?>[
    for (final TopicRef topic in claim.writes) _encodeTopic(topic),
  ],
};

// Every decoder below reads the JSON value at its path, the JSONPath of that
// value from the document's root `$` (`$` is the definition object itself for
// decodeTopologyDefinition), and throws FormatException('$path: $problem') for
// a value of the wrong shape or one that breaks a rule of the decoder: the
// path names the place, the problem says what must be there, and neither
// renders the value found, which may be large. The IR, claim and graph
// factories are the rule book for what a definition, an edge, a claim and a
// graph may hold: _build turns their ArgumentError into that exception.

// The definition object at path: its id, scope and transforms. Its reads and
// writes are read for their shape and compared with the ones the definition
// derives from its transforms.
TopologyDefinition _decodeDefinition(Object? json, String path) {
  final Map<String, Object?> object = _object(json, path, const <String>{
    'topologyId',
    'scope',
    'reads',
    'writes',
    'transforms',
  });
  final String topologyId = _string(object['topologyId'], '$path.topologyId');
  final Scope scope = _named(Scope.values, object['scope'], '$path.scope');
  final List<TopicRef> reads = _decodeTopics(object['reads'], '$path.reads');
  final List<TopicRef> writes = _decodeTopics(object['writes'], '$path.writes');
  final List<TransformEdge> transforms = _list(
    object['transforms'],
    '$path.transforms',
    _decodeEdge,
  );
  final TopologyDefinition definition = _build(
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
}

// The edge object at path: a write when it has no combinator, a reduceInto,
// or a stage, each with exactly the keys its form allows.
TransformEdge _decodeEdge(Object? json, String path) {
  if (json is! Map || !json.containsKey('combinator')) {
    return _decodeWrite(json, path);
  }
  final CombinatorKind combinator = _named(
    CombinatorKind.values,
    json['combinator'],
    '$path.combinator',
  );
  return combinator == CombinatorKind.reduceInto
      ? _decodeReduceInto(json, path)
      : _decodeStage(combinator, json, path);
}

// The write edge object at path: one input and the topic it publishes to.
TransformEdge _decodeWrite(Object? json, String path) {
  final Map<String, Object?> write = _object(json, path, const <String>{
    'inputs',
    'output',
  });
  final EdgeInput input = _decodeOneInput(write['inputs'], '$path.inputs');
  final TopicRef output = _decodeTopic(write['output'], '$path.output');
  return _build(path, () => TransformEdge.write(output, input));
}

// The reduceInto edge object at path: one input, the state topic it folds
// into and the reducer.
TransformEdge _decodeReduceInto(Object? json, String path) {
  final Map<String, Object?> reduce = _object(json, path, const <String>{
    'combinator',
    'inputs',
    'output',
    'transformer',
  });
  final EdgeInput events = _decodeOneInput(reduce['inputs'], '$path.inputs');
  final TopicRef output = _decodeTopic(reduce['output'], '$path.output');
  final FunctionRef reducer = _decodeFunction(
    reduce['transformer'],
    '$path.transformer',
  );
  return _build(path, () => TransformEdge.reduceInto(output, events, reducer));
}

// The stage edge object at path, whose combinator is combinator: its inputs
// and the transformer, duration and retry it has.
TransformEdge _decodeStage(
  CombinatorKind combinator,
  Object? json,
  String path,
) {
  final Map<String, Object?> stage = _object(
    json,
    path,
    const <String>{'combinator', 'inputs'},
    const <String>{'transformer', 'durationMicros', 'retry'},
  );
  final List<EdgeInput> inputs = _list(
    stage['inputs'],
    '$path.inputs',
    _decodeInput,
  );
  final FunctionRef? transformer = stage.containsKey('transformer')
      ? _decodeFunction(stage['transformer'], '$path.transformer')
      : null;
  final Duration? duration = stage.containsKey('durationMicros')
      ? Duration(
          microseconds: _integer(
            stage['durationMicros'],
            '$path.durationMicros',
          ),
        )
      : null;
  final FunctionRef? retry = stage.containsKey('retry')
      ? _decodeFunction(stage['retry'], '$path.retry')
      : null;
  return _build(
    path,
    () => TransformEdge.stage(
      combinator,
      inputs,
      transformer: transformer,
      duration: duration,
      retry: retry,
    ),
  );
}

// The inputs array at path of a write or a reduceInto: exactly one input.
EdgeInput _decodeOneInput(Object? json, String path) {
  final List<EdgeInput> inputs = _list(json, path, _decodeInput);
  if (inputs.length != 1) {
    _reject(path, 'must hold exactly one input');
  }
  return inputs.single;
}

// The input object at path: {"edge": n}, or {"topic": ...} with a dedup when
// the object has one, which only a read of a state topic may.
EdgeInput _decodeInput(Object? json, String path) {
  if (json is Map && json.containsKey('edge')) {
    final Map<String, Object?> stage = _object(json, path, const <String>{
      'edge',
    });
    return StageInput(_integer(stage['edge'], '$path.edge'));
  }
  final Map<String, Object?> read = _object(
    json,
    path,
    const <String>{'topic'},
    const <String>{'dedup'},
  );
  final TopicRef topic = _decodeTopic(read['topic'], '$path.topic');
  if (!read.containsKey('dedup')) {
    return TopicInput(topic);
  }
  final Dedup dedup = _named(Dedup.values, read['dedup'], '$path.dedup');
  if (topic.variant != TopicVariant.state) {
    _reject('$path.dedup', 'may be given only on a read of a state topic');
  }
  return TopicInput(topic, dedup: dedup);
}

// The topic reference object at path: a name, which may be empty, a variant
// by name and a type name, which may not.
TopicRef _decodeTopic(Object? json, String path) {
  final Map<String, Object?> topic = _object(json, path, const <String>{
    'name',
    'variant',
    'typeName',
  });
  final String name = _string(topic['name'], '$path.name');
  final TopicVariant variant = _named(
    TopicVariant.values,
    topic['variant'],
    '$path.variant',
  );
  final String typeName = _string(topic['typeName'], '$path.typeName');
  if (typeName.isEmpty) {
    _reject('$path.typeName', 'must not be empty');
  }
  return TopicRef(name: name, variant: variant, typeName: typeName);
}

// The array of topic references at path, none repeated.
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

// The function reference object at path: a non-empty name, or null for an
// anonymous function.
FunctionRef _decodeFunction(Object? json, String path) {
  final Map<String, Object?> function = _object(json, path, const <String>{
    'name',
  });
  return switch (function['name']) {
    null => const FunctionRef.anonymous(),
    final String name when name.isNotEmpty => FunctionRef.named(name),
    _ => _reject('$path.name', 'must be a non-empty string or null'),
  };
}

// The claim object at path: a service, page or executor source rendering, a
// scope and the topics it writes.
ShellClaim _decodeClaim(Object? json, String path) {
  final Map<String, Object?> claim = _object(json, path, const <String>{
    'source',
    'scope',
    'writes',
  });
  final MessageSource source = switch (MessageSource.tryParse(
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
  final Scope scope = _named(Scope.values, claim['scope'], '$path.scope');
  final List<TopicRef> writes = _decodeTopics(claim['writes'], '$path.writes');
  return _build(
    path,
    () => ShellClaim(source: source, scope: scope, writes: writes.toSet()),
  );
}

// Throws unless the topology ids of topologies, the array at path, are
// distinct: TopologyGraph would count equal definitions once.
void _checkDistinctIds(List<TopologyDefinition> topologies, String path) {
  final Map<String, int> first = <String, int>{};
  for (int i = 0; i < topologies.length; i++) {
    final int seen = first.putIfAbsent(topologies[i].topologyId, () => i);
    if (seen != i) {
      _reject('$path[$i].topologyId', 'repeats the id of $path[$seen]');
    }
  }
}

// Throws unless listed, the array at path with no topic repeated, holds
// exactly the topics of derived, which the definition derived from its edges;
// what says in the message which topics those are.
void _checkSameTopics(
  List<TopicRef> listed,
  Set<TopicRef> derived,
  String path,
  String what,
) {
  if (listed.length != derived.length || !derived.containsAll(listed)) {
    _reject(path, 'must list each topic $what, once');
  }
}

// json as a JSON object at path whose keys are all of required and some of
// optional, and no other. A Map of any type is read, provided its keys are
// all strings.
Map<String, Object?> _object(
  Object? json,
  String path,
  Set<String> required, [
  Set<String> optional = const <String>{},
]) {
  if (json is! Map || json.keys.any((Object? key) => key is! String)) {
    _reject(path, 'must be an object');
  }
  final Map<String, Object?> object = json.cast<String, Object?>();
  for (final String key in required) {
    if (!object.containsKey(key)) {
      _reject('$path.$key', 'is missing');
    }
  }
  for (final String key in object.keys) {
    if (!required.contains(key) && !optional.contains(key)) {
      _reject(path, 'must not have the key ${jsonEncode(key)}');
    }
  }
  return object;
}

// json as a JSON array at path, each element decoded by decode at its own
// path. A List of any type is read; a Set or another Iterable is no array.
List<T> _list<T>(
  Object? json,
  String path,
  T Function(Object? json, String path) decode,
) {
  if (json is! List) {
    _reject(path, 'must be an array');
  }
  return <T>[
    for (int i = 0; i < json.length; i++) decode(json[i], '$path[$i]'),
  ];
}

// json as a string.
String _string(Object? json, String path) =>
    json is String ? json : _reject(path, 'must be a string');

// json as a non-negative integer, which is every number the schema has an index
// or a duration be: an int, or a double with no fraction below 2^63, which JSON
// Schema also counts as an integer.
int _integer(Object? json, String path) => switch (json) {
  final int n when n >= 0 => n,
  final double d when d >= 0 && d < _twoTo63 && d == d.truncateToDouble() =>
    d.toInt(),
  _ => _reject(path, 'must be a non-negative integer'),
};

// 2^63, the first double above every int.
const double _twoTo63 = 9223372036854775808.0;

// The value of values whose name is json. The lookup is a map of the names,
// since byName throws ArgumentError for an unknown name.
T _named<T extends Enum>(List<T> values, Object? json, String path) =>
    (json is String ? values.asNameMap()[json] : null) ??
    _reject(
      path,
      'must be one of ${values.map((T value) => value.name).join(', ')}',
    );

// What build returns: the ArgumentError an IR, claim or graph factory throws
// becomes a FormatException at path that names the argument and keeps the
// factory's message. ArgumentError.toString() would render the invalid value.
T _build<T>(String path, T Function() build) {
  try {
    return build();
  } on ArgumentError catch (error) {
    _reject(path, '${error.name}: ${error.message}');
  }
}

// Throws the FormatException that says what path must hold.
Never _reject(String path, String problem) =>
    throw FormatException('$path: $problem');
