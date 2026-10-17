// Stand-in for the topic catalog generator of topic-codegen@v1: topics.md
// from the topics document and, when given, the topology graph.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

import 'markdown.dart';
import 'topics_document.dart';

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _list(Iterable<String> items) =>
    items.isEmpty ? 'none' : items.join(', ');

String _writer(MessageSource source, Scope scope) =>
    '${codeSpan(source.toString())} (${scope.name})';

/// topics.md for [doc] and, when not null, [graph].
String renderCatalog(TopicsDocument doc, TopologyGraph? graph) {
  final b = StringBuffer();
  void line([String text = '']) => b.writeln(text);
  void table(List<String> header, List<List<String>> rows) {
    line('| ${header.join(' | ')} |');
    line('| ${header.map((_) => '---').join(' | ')} |');
    for (final r in rows) {
      line('| ${r.map(cell).join(' | ')} |');
    }
  }

  List<String> writtenBy(String name) => [
    for (final t in graph!.topologies)
      if (t.writes.any((r) => r.name == name))
        _writer(TopologySource(t.topologyId), t.scope),
    for (final c in graph.claims)
      if (c.writes.any((r) => r.name == name)) _writer(c.source, c.scope),
  ];
  List<String> readBy(String name) => [
    for (final t in graph!.topologies)
      if (t.reads.any((r) => r.name == name))
        _writer(TopologySource(t.topologyId), t.scope),
  ];

  final topicCount = doc.domains.fold<int>(0, (n, d) => n + d.topics.length);
  line('<!-- GENERATED CODE - DO NOT MODIFY BY HAND. -->');
  line(
    graph == null
        ? '<!-- nidana_dart_codegen from topics.yaml (topic-codegen@v1). -->'
        : '<!-- nidana_dart_codegen from topics.yaml and topology-graph.json (topic-codegen@v1). -->',
  );
  line();
  line('# Topic catalog');
  line();
  final summary =
      '${_count(topicCount, 'topic', 'topics')} in ${_count(doc.domains.length, 'domain', 'domains')}, from `topics.yaml`.';
  line(
    graph == null
        ? '$summary No topology graph was given, so readers and writers are not listed.'
        : '$summary Readers and writers from `topology-graph.json`: '
              '${_count(graph.topologies.length, 'topology', 'topologies')}, '
              '${_count(graph.claims.length, 'shell claim', 'shell claims')}.',
  );
  line();
  table(
    ['Domain', 'Owner', 'Registry', 'Topics'],
    [
      for (final d in doc.domains)
        [
          codeSpan(d.key),
          escapeAngles(d.owner),
          codeSpan(d.className),
          '${d.topics.length}',
        ],
    ],
  );

  for (final d in doc.domains) {
    line();
    line('## Domain ${codeSpan(d.key)}');
    line();
    line(
      'Owner: ${escapeAngles(d.owner)}. Registry: ${codeSpan(d.className)}.',
    );
    for (final t in d.topics) {
      line();
      line('### ${codeSpan(t.name)}');
      line();
      if (t.description != null) {
        for (final l in descriptionLines(escapeAngles(t.description!))) {
          line(l);
        }
        line();
      }
      table(
        ['Property', 'Value'],
        [
          ['Member', codeSpan('${d.className}.${t.member}')],
          ['Variant', t.variant.name],
          ['Type', codeSpan(t.type)],
          if (t.variant == TopicVariantSpec.state) ...[
            ['Initial', codeSpan(t.initial!)],
            ['Dedup', t.dedupNone ? 'none' : 'equality'],
          ],
          if (t.variant == TopicVariantSpec.replay)
            ['Buffer size', '${t.bufferSize}'],
          ['Sensitive', t.sensitive ? 'yes' : 'no'],
          ['Tracing', t.tracingDisabled ? 'disabled' : 'enabled'],
          if (graph != null) ...[
            ['Written by', _list(writtenBy(t.name))],
            ['Read by', _list(readBy(t.name))],
          ],
        ],
      );
    }
  }

  if (graph != null) {
    line();
    line('## Topologies');
    line();
    if (graph.topologies.isEmpty) {
      line('None.');
    } else {
      table(
        ['Topology', 'Scope', 'Reads', 'Writes'],
        [
          for (final t in graph.topologies)
            [
              codeSpan(t.topologyId),
              t.scope.name,
              _list(t.reads.map((r) => codeSpan(r.name))),
              _list(t.writes.map((r) => codeSpan(r.name))),
            ],
        ],
      );
    }
    line();
    line('## Shell claims');
    line();
    if (graph.claims.isEmpty) {
      line('None.');
    } else {
      table(
        ['Source', 'Scope', 'Writes'],
        [
          for (final c in graph.claims)
            [
              codeSpan(c.source.toString()),
              c.scope.name,
              _list(c.writes.map((r) => codeSpan(r.name))),
            ],
        ],
      );
    }
    final declared = {
      for (final d in doc.domains)
        for (final t in d.topics) t.name,
    };
    final outside = graph.topics.where((r) => !declared.contains(r.name));
    line();
    line('## Topics outside topics.yaml');
    line();
    if (outside.isEmpty) {
      line('None.');
    } else {
      table(
        ['Topic', 'Variant', 'Type', 'Written by', 'Read by'],
        [
          for (final r in outside)
            [
              codeSpan(r.name),
              r.variant.name,
              codeSpan(r.typeName),
              _list(writtenBy(r.name)),
              _list(readBy(r.name)),
            ],
        ],
      );
    }
  }
  return b.toString();
}
