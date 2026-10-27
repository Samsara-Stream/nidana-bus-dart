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
  const String path = r'$';
  final Map<String, Object?> document = _object(json, path, const <String>{
    'format',
    'topologies',
    'claims',
  });
  if (document['format'] != _format) {
    _reject('$path.format', 'must be "$_format"');
  }
  final List<TopologyDefinition> topologies = _list(
    document['topologies'],
    '$path.topologies',
    _decodeDefinition,
  );
  _checkDistinctIds(topologies, '$path.topologies');
  final List<ShellClaim> claims = _list(
    document['claims'],
    '$path.claims',
    _decodeClaim,
  );
  return _build(
    path,
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

  // The encoding as _indented renders it, then a newline (topology-ir@v1,
  // The JSON form).
  @override
  String render(TopologyGraph graph) =>
      '${_indented.convert(encodeTopologyGraph(graph))}\n';
}

// The format of a graph document of this version.
const String _format = 'topology-ir@v1';

// The JSON text of a graph document, every level indented by two spaces.
const JsonEncoder _indented = JsonEncoder.withIndent('  ');

// ------------------------------------------------------------ encoding

// An edge: combinator, absent for a write; inputs; then output, transformer,
// durationMicros and retry, each only where the edge has it.
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

// A topic input, with dedup only when the read gave one, or a stage input.
Map<String, Object?> _encodeInput(EdgeInput input) => switch (input) {
  TopicInput(:final TopicRef topic, :final Dedup? dedup) => <String, Object?>{
    'topic': _encodeTopic(topic),
    if (dedup != null) 'dedup': dedup.name,
  },
  StageInput(:final int edge) => <String, Object?>{'edge': edge},
};

// A topic reference: its name, its variant by enum name, its type name.
Map<String, Object?> _encodeTopic(TopicRef topic) => <String, Object?>{
  'name': topic.name,
  'variant': topic.variant.name,
  'typeName': topic.typeName,
};

// A function reference: its name, null when anonymous.
Map<String, Object?> _encodeFunction(FunctionRef function) => <String, Object?>{
  'name': function.name,
};

// A shell claim: its source's rendering, its scope by enum name, its writes.
Map<String, Object?> _encodeClaim(ShellClaim claim) => <String, Object?>{
  'source': claim.source.toString(),
  'scope': claim.scope.name,
  'writes': <Object?>[
    for (final TopicRef topic in claim.writes) _encodeTopic(topic),
  ],
};

// ------------------------------------------------------------ decoding
//
// Each decoder below reads the JSON value at [path], a JSONPath from the
// document's root `$`, and throws FormatException('$path: problem') for
// anything the schema or a decoder rule rejects. A message names the place
// and what the place must hold, never the value found there, which may be
// large or contain itself.

// The definition object at [path]: the definition rules (through
// TopologyDefinition), then reads and writes equal to the topics its edges
// read and its sink edges write, each listed once.
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

// The edge object at [path]: a write when it has no combinator, a reduceInto,
// or a stage, each with exactly the keys its form allows.
TransformEdge _decodeEdge(Object? json, String path) {
  if (json is! Map || !json.containsKey('combinator')) {
    final Map<String, Object?> write = _object(json, path, const <String>{
      'inputs',
      'output',
    });
    final EdgeInput input = _decodeOneInput(write['inputs'], '$path.inputs');
    final TopicRef output = _decodeTopic(write['output'], '$path.output');
    return _build(path, () => TransformEdge.write(output, input));
  }
  final CombinatorKind combinator = _named(
    CombinatorKind.values,
    json['combinator'],
    '$path.combinator',
  );
  if (combinator == CombinatorKind.reduceInto) {
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
    return _build(
      path,
      () => TransformEdge.reduceInto(output, events, reducer),
    );
  }
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

// The inputs array at [path] of a write or a reduceInto: exactly one input.
EdgeInput _decodeOneInput(Object? json, String path) {
  final List<EdgeInput> inputs = _list(json, path, _decodeInput);
  if (inputs.length != 1) {
    _reject(path, 'must hold exactly one input');
  }
  return inputs.single;
}

// The input object at [path]: {"edge": n}, or {"topic": ...} with a dedup
// only on a read of a state topic. The index is checked before StageInput
// asserts it.
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

// The topic reference object at [path], its typeName not empty.
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

// The array of topic references at [path], none repeated.
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

// The function reference object at [path]: a non-empty name, or null.
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

// The claim object at [path]: a service, page or executor source rendering,
// a scope, and its state topics, none repeated (through ShellClaim).
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

// Throws unless the topology ids of [topologies], the array at [path], are
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

// Throws unless [listed], the array at [path] with no topic repeated, holds
// exactly the topics of [derived], which [what] names.
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

// [json] as a JSON object at [path] whose keys are all of [required] and
// some of [optional], and no other.
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

// [json] as a JSON array at [path], each element decoded by [decode] at its
// own path.
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

// [json] as a string.
String _string(Object? json, String path) =>
    json is String ? json : _reject(path, 'must be a string');

// [json] as a non-negative integer, the schema's only integers: an int, or a
// double with no fraction below 2^63, which JSON Schema also counts as an
// integer.
int _integer(Object? json, String path) => switch (json) {
  final int n when n >= 0 => n,
  final double d when d >= 0 && d < _twoTo63 && d == d.truncateToDouble() =>
    d.toInt(),
  _ => _reject(path, 'must be a non-negative integer'),
};

// 2^63, the first double above every int.
const double _twoTo63 = 9223372036854775808.0;

// The value of [values] whose name is [json].
T _named<T extends Enum>(List<T> values, Object? json, String path) =>
    (json is String ? values.asNameMap()[json] : null) ??
    _reject(
      path,
      'must be one of ${values.map((T value) => value.name).join(', ')}',
    );

// What [build] returns: the ArgumentError an IR, claim or graph factory
// throws becomes a FormatException at [path] that names the argument and
// keeps the factory's message.
T _build<T>(String path, T Function() build) {
  try {
    return build();
  } on ArgumentError catch (error) {
    _reject(path, '${error.name}: ${error.message}');
  }
}

// Throws the FormatException that says what [path] must hold, or what is
// wrong there.
Never _reject(String path, String problem) =>
    throw FormatException('$path: $problem');
