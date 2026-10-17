// Stand-in for nidana_dart_codegen's topics.yaml reader (experiment only):
// parses a topics document and checks every rule topic-codegen@v1 states,
// the schema's and the generator's own (hsdd/contract/topic-codegen.md,
// "The topics document").
import 'package:yaml/yaml.dart';

enum TopicVariantSpec { state, event, replay }

/// A rule violation at a 1-based line and column of topics.yaml.
final class Violation {
  const Violation(this.line, this.column, this.message);
  final int line;
  final int column;
  final String message;

  String render(String path) => '$path:$line:$column: $message';
}

final class TopicSpec {
  const TopicSpec({
    required this.key,
    required this.name,
    required this.member,
    required this.type,
    required this.variant,
    required this.initial,
    required this.dedupNone,
    required this.bufferSize,
    required this.sensitive,
    required this.tracingDisabled,
    required this.description,
  });

  final String key;
  final String name;
  final String member;
  final String type;
  final TopicVariantSpec variant;

  /// The Dart expression of a state topic's initial value; null otherwise.
  final String? initial;
  final bool dedupNone;
  final int? bufferSize;
  final bool sensitive;
  final bool tracingDisabled;
  final String? description;
}

final class DomainSpec {
  const DomainSpec({
    required this.key,
    required this.className,
    required this.owner,
    required this.imports,
    required this.topics,
  });

  final String key;
  final String className;
  final String owner;
  final List<String> imports;
  final List<TopicSpec> topics;
}

final class TopicsDocument {
  const TopicsDocument(this.domains);
  final List<DomainSpec> domains;
}

/// The result of reading topics.yaml: a document, or every violation found.
final class ReadResult {
  const ReadResult._(this.document, this.violations);
  final TopicsDocument? document;
  final List<Violation> violations;
}

final _segment = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');
final _topicKey = RegExp(
  r'^[a-z][a-z0-9]*(-[a-z0-9]+)*(\.[a-z][a-z0-9]*(-[a-z0-9]+)*)?$',
);
final _trimmedLine = RegExp(r'^\S(?:.*\S)?$');
final _nonBlank = RegExp(r'\S');
final _importUri = RegExp(
  r'''^(dart:[a-z_][a-z0-9_]*|[^\s'"\\]+\.dart)$''',
);

/// Dart's reserved words and the names Object declares, which no static
/// member of a registry class may take (probe/names/output.txt).
const reservedMembers = <String>{
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  'hashCode', 'runtimeType', 'toString', 'noSuchMethod',
};

String upperCamel(String key) =>
    key.split(RegExp(r'[.-]')).map(_capitalize).join();

String lowerCamel(String key) {
  final parts = key.split(RegExp(r'[.-]'));
  return parts.first + parts.skip(1).map(_capitalize).join();
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

ReadResult readTopicsDocument(String source) {
  final violations = <Violation>[];
  void at(YamlNode node, String message) => violations.add(
    Violation(node.span.start.line + 1, node.span.start.column + 1, message),
  );

  final YamlNode root;
  try {
    root = loadYamlNode(source);
  } on YamlException catch (e) {
    final start = e.span?.start;
    return ReadResult._(null, [
      Violation((start?.line ?? 0) + 1, (start?.column ?? 0) + 1, e.message),
    ]);
  }

  YamlNode? keyNode(YamlMap map, String key) {
    for (final k in map.nodes.keys) {
      if (k is YamlNode && k.value == key) return k;
    }
    return null;
  }

  void closed(YamlMap map, Set<String> allowed, String where) {
    for (final k in map.nodes.keys) {
      final node = k as YamlNode;
      if (node.value is! String || !allowed.contains(node.value)) {
        at(node, 'unknown key "${node.value}" in $where');
      }
    }
  }

  String? string(
    YamlMap map,
    String key,
    String where, {
    required bool required,
    RegExp? pattern,
    String? patternMessage,
  }) {
    final node = map.nodes[key];
    if (node == null) {
      if (required) at(map, '$where: "$key" is required');
      return null;
    }
    final value = node.value;
    if (value is! String) {
      at(node, '$where: "$key" must be a string');
      return null;
    }
    if (pattern != null && !pattern.hasMatch(value)) {
      at(node, '$where: "$key" ${patternMessage ?? 'is malformed'}');
      return null;
    }
    return value;
  }

  if (root is! YamlMap) {
    at(root, 'the document must be a mapping');
    return ReadResult._(null, violations);
  }
  closed(root, {'domains'}, 'the document');
  final domainsNode = root.nodes['domains'];
  if (domainsNode == null) {
    at(root, 'the document: "domains" is required');
    return ReadResult._(null, violations);
  }
  if (domainsNode is! YamlMap || domainsNode.isEmpty) {
    at(domainsNode, '"domains" must be a mapping with at least one domain');
    return ReadResult._(null, violations);
  }

  final domains = <DomainSpec>[];
  final classes = <String, String>{};
  for (final entry in domainsNode.nodes.entries) {
    final kNode = entry.key as YamlNode;
    final key = kNode.value;
    if (key is! String || !_segment.hasMatch(key)) {
      at(kNode, 'domain key "$key" must be one lowercase kebab-case segment');
      continue;
    }
    final where = 'domain "$key"';
    final dNode = entry.value;
    if (dNode is! YamlMap) {
      at(dNode, '$where must be a mapping');
      continue;
    }
    closed(dNode, {'owner', 'dart', 'topics'}, where);
    final owner = string(
      dNode,
      'owner',
      where,
      required: true,
      pattern: _trimmedLine,
      patternMessage: 'must be one non-blank line without surrounding spaces',
    );

    final imports = <String>[];
    final dartNode = dNode.nodes['dart'];
    if (dartNode != null) {
      if (dartNode is! YamlMap) {
        at(dartNode, '$where: "dart" must be a mapping');
      } else {
        closed(dartNode, {'imports'}, '$where "dart"');
        final importsNode = dartNode.nodes['imports'];
        if (importsNode != null) {
          if (importsNode is! YamlList) {
            at(importsNode, '$where: "imports" must be a list');
          } else {
            for (final item in importsNode.nodes) {
              final uri = item.value;
              if (uri is! String || !_importUri.hasMatch(uri)) {
                at(item, '$where: import "$uri" is not a dart: URI or a .dart URI');
              } else if (imports.contains(uri)) {
                at(item, '$where: import "$uri" is listed twice');
              } else {
                imports.add(uri);
              }
            }
          }
        }
      }
    }

    final className = '${upperCamel(key)}Topics';
    final clash = classes[className];
    if (clash != null) {
      at(kNode, 'domain "$key" and domain "$clash" both name the class $className');
    } else {
      classes[className] = key;
    }

    final topicsNode = dNode.nodes['topics'];
    final topics = <TopicSpec>[];
    if (topicsNode == null) {
      at(dNode, '$where: "topics" is required');
    } else if (topicsNode is! YamlMap || topicsNode.isEmpty) {
      at(topicsNode, '$where: "topics" must be a mapping with at least one topic');
    } else {
      final members = <String, String>{};
      for (final tEntry in topicsNode.nodes.entries) {
        final tk = tEntry.key as YamlNode;
        final tKey = tk.value;
        if (tKey is! String || !_topicKey.hasMatch(tKey)) {
          at(tk, 'topic key "$tKey" must be one or two lowercase kebab-case segments joined by "."');
          continue;
        }
        final tWhere = 'topic "$key.$tKey"';
        final member = lowerCamel(tKey);
        if (reservedMembers.contains(member)) {
          at(tk, '$tWhere: its member name "$member" is reserved in Dart or declared by Object');
        }
        final mClash = members[member];
        if (mClash != null) {
          at(tk, '$tWhere and topic "$key.$mClash" both name the member $member');
        } else {
          members[member] = tKey;
        }
        final tNode = tEntry.value;
        if (tNode is! YamlMap) {
          at(tNode, '$tWhere must be a mapping');
          continue;
        }
        closed(tNode, {
          'type', 'variant', 'initial', 'dedup', 'buffer-size', 'sensitive',
          'tracing', 'description',
        }, tWhere);
        final type = string(
          tNode,
          'type',
          tWhere,
          required: true,
          pattern: _trimmedLine,
          patternMessage: 'must be one non-blank line without surrounding spaces',
        );
        final variantText = string(tNode, 'variant', tWhere, required: true);
        TopicVariantSpec? variant;
        if (variantText != null) {
          variant = TopicVariantSpec.values
              .where((v) => v.name == variantText)
              .firstOrNull;
          if (variant == null) {
            at(tNode.nodes['variant']!, '$tWhere: "variant" must be state, event or replay');
          }
        }

        String? initial;
        final initialNode = tNode.nodes['initial'];
        if (variant == TopicVariantSpec.state) {
          if (initialNode == null) {
            at(tk, '$tWhere: a state topic requires "initial"');
          } else {
            final v = initialNode.value;
            if (v == null || v is bool || v is int) {
              initial = '$v';
            } else if (v is double) {
              if (v.isFinite) {
                initial = '$v';
              } else {
                at(initialNode, '$tWhere: "initial" must be a finite number');
              }
            } else if (v is String) {
              if (_trimmedLine.hasMatch(v)) {
                initial = v;
              } else {
                at(initialNode, '$tWhere: "initial" must be one non-blank line without surrounding spaces');
              }
            } else {
              at(initialNode, '$tWhere: "initial" must be a string, a number, a boolean or null');
            }
          }
        } else if (variant != null && initialNode != null) {
          at(initialNode, '$tWhere: only a state topic takes "initial"');
        }

        var dedupNone = false;
        final dedupNode = tNode.nodes['dedup'];
        if (dedupNode != null) {
          if (variant != null && variant != TopicVariantSpec.state) {
            at(dedupNode, '$tWhere: only a state topic takes "dedup"');
          } else if (dedupNode.value == 'none') {
            dedupNone = true;
          } else if (dedupNode.value != 'equality') {
            at(dedupNode, '$tWhere: "dedup" must be equality or none');
          }
        }

        int? bufferSize;
        final bufferNode = tNode.nodes['buffer-size'];
        if (variant == TopicVariantSpec.replay) {
          if (bufferNode == null) {
            at(tk, '$tWhere: a replay topic requires "buffer-size"');
          } else if (bufferNode.value is! int || (bufferNode.value as int) < 1) {
            at(bufferNode, '$tWhere: "buffer-size" must be an integer of at least 1');
          } else {
            bufferSize = bufferNode.value as int;
          }
        } else if (variant != null && bufferNode != null) {
          at(bufferNode, '$tWhere: only a replay topic takes "buffer-size"');
        }

        var sensitive = false;
        final sensitiveNode = tNode.nodes['sensitive'];
        if (sensitiveNode != null) {
          if (sensitiveNode.value is! bool) {
            at(sensitiveNode, '$tWhere: "sensitive" must be true or false');
          } else {
            sensitive = sensitiveNode.value as bool;
          }
        }

        var tracingDisabled = false;
        final tracingNode = tNode.nodes['tracing'];
        if (tracingNode != null) {
          if (tracingNode.value == 'disabled') {
            tracingDisabled = true;
          } else if (tracingNode.value != 'enabled') {
            at(tracingNode, '$tWhere: "tracing" must be enabled or disabled');
          }
        }

        final description = string(
          tNode,
          'description',
          tWhere,
          required: false,
          pattern: _nonBlank,
          patternMessage: 'must not be blank',
        );

        if (type != null && variant != null) {
          topics.add(
            TopicSpec(
              key: tKey,
              name: '$key.$tKey',
              member: member,
              type: type,
              variant: variant,
              initial: initial,
              dedupNone: dedupNone,
              bufferSize: bufferSize,
              sensitive: sensitive,
              tracingDisabled: tracingDisabled,
              description: description,
            ),
          );
        }
      }
    }
    if (owner != null) {
      domains.add(
        DomainSpec(
          key: key,
          className: className,
          owner: owner,
          imports: List.unmodifiable(imports),
          topics: List.unmodifiable(topics),
        ),
      );
    }
  }
  // keyNode is kept for diagnostics that point at a key; unused otherwise.
  keyNode;
  if (violations.isNotEmpty) return ReadResult._(null, violations);
  return ReadResult._(TopicsDocument(List.unmodifiable(domains)), const []);
}
