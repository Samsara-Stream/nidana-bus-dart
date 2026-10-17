// Stand-in for the registry generator of topic-codegen@v1: one Dart library
// declaring a registry class per domain.
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';

import 'markdown.dart';
import 'topics_document.dart';

const contractsImport =
    'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// topics.g.dart for [doc], formatted.
String renderRegistry(TopicsDocument doc) {
  final b = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// nidana_dart_codegen from topics.yaml (topic-codegen@v1).');

  final uris = <String>{contractsImport};
  for (final d in doc.domains) {
    uris.addAll(d.imports);
  }
  int group(String uri) => uri.startsWith('dart:')
      ? 0
      : uri.startsWith('package:')
      ? 1
      : 2;
  final sorted = uris.toList()
    ..sort((a, b) {
      final g = group(a).compareTo(group(b));
      return g != 0 ? g : a.compareTo(b);
    });
  int? last;
  for (final uri in sorted) {
    if (group(uri) != last) b.writeln();
    last = group(uri);
    b.writeln("import '$uri';");
  }

  for (final d in doc.domains) {
    b
      ..writeln()
      ..writeln(
        '/// Topics of the `${d.key}` domain, owned by ${escapeAngles(d.owner)}.',
      )
      ..writeln('abstract final class ${d.className} {');
    var first = true;
    for (final t in d.topics) {
      if (!first) b.writeln();
      first = false;
      if (t.description != null) {
        for (final line in descriptionLines(escapeAngles(t.description!))) {
          b.writeln(line.isEmpty ? '  ///' : '  /// $line');
        }
      }
      final cls = switch (t.variant) {
        TopicVariantSpec.state => 'StateTopic',
        TopicVariantSpec.event => 'EventTopic',
        TopicVariantSpec.replay => 'ReplayTopic',
      };
      final type = '$cls<${t.type}>';
      final args = <String>["name: '${t.name}'"];
      if (t.variant == TopicVariantSpec.state) args.add('initial: ${t.initial}');
      if (t.variant == TopicVariantSpec.replay) {
        args.add('bufferSize: ${t.bufferSize}');
      }
      if (t.dedupNone) args.add('dedup: Dedup.none');
      if (t.sensitive) args.add('sensitive: true');
      if (t.tracingDisabled) args.add('tracing: Tracing.disabled');
      b.writeln('  static final $type ${t.member} = $type(${args.join(', ')},);');
    }
    b.writeln('}');
  }
  return DartFormatter(languageVersion: Version(3, 13, 0)).format(b.toString());
}
