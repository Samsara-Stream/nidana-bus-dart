import 'package:build/build.dart';

/// Writes lib/topics.g.dart from lib/topics.yaml, as topic-codegen@v1's
/// builder does, with a trivial generator.
Builder topicsBuilder(BuilderOptions options) => _TopicsBuilder();

class _TopicsBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const <String, List<String>>{
    '^lib/topics.yaml': <String>['lib/topics.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final String source = await buildStep.readAsString(buildStep.inputId);
    final int lines = source.split('\n').where((String l) => l.trim().isNotEmpty).length;
    await buildStep.writeAsString(buildStep.allowedOutputs.single,
        '// GENERATED CODE - DO NOT MODIFY BY HAND.\nconst int topicLines = $lines;\n');
  }
}
