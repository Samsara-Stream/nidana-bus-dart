// P1: what package:yaml 3.1.4 does with the inputs topic-codegen@v1 relies on.
import 'package:yaml/yaml.dart';

void show(String label, String source) {
  try {
    final doc = loadYaml(source);
    final rendered = doc is Map ? doc.keys.toList() : doc;
    print('$label: ok ${doc.runtimeType} $rendered');
  } on YamlException catch (e) {
    print('$label: YamlException ${e.message} at ${e.span?.start.line}:${e.span?.start.column}');
  } catch (e) {
    print('$label: ${e.runtimeType} $e');
  }
}

void main() {
  show('duplicate key', 'a: 1\nb: 2\na: 3\n');
  show('key order kept', 'zeta: 1\nalpha: 2\nmid: 3\n');
  show('JSON document', '{"domains": {"auth": {"owner": "x", "topics": {}}}}');
  show('multiple documents', 'a: 1\n---\nb: 2\n');
  show('syntax error', 'a: [1, 2\n');
  final scalars = loadYaml('''
i: 0
f: 1.0
g: 0.5
e: 1e3
inf: .inf
nan: .nan
t: true
yes: yes
n: null
tilde: ~
empty:
s: AuthState.initializing()
q: "'x'"
big: 12345678901234567890
''') as YamlMap;
  for (final k in scalars.keys) {
    final v = scalars[k];
    print('scalar $k: ${v.runtimeType} ${v is double ? '${v.toString()} finite=${v.isFinite}' : v}');
  }
  final spans = loadYamlNode('domains:\n  auth:\n    owner: x\n') as YamlMap;
  final auth = (spans.nodes['domains'] as YamlMap).nodes['auth'] as YamlMap;
  final owner = auth.nodes['owner']!;
  print('span of owner value: line ${owner.span.start.line + 1}, column ${owner.span.start.column + 1}');
  final keyNode = auth.nodes.keys.firstWhere((k) => (k as YamlNode).value == 'owner') as YamlNode;
  print('span of owner key: line ${keyNode.span.start.line + 1}, column ${keyNode.span.start.column + 1}');
}
