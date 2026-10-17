/// Stand-in for nidana_dart_codegen's build_runner builder (experiment only):
/// lib/topics.yaml to lib/topics.g.dart, through the same pure function the
/// `generate` command calls.
library;

import 'package:build/build.dart';

import 'src/generate.dart';

Builder topicsBuilder(BuilderOptions options) => const _TopicsBuilder();

final class _TopicsBuilder implements Builder {
  const _TopicsBuilder();

  @override
  Map<String, List<String>> get buildExtensions => const {
    '^lib/topics.yaml': ['lib/topics.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final result = generateRegistry(
      await buildStep.readAsString(buildStep.inputId),
      buildStep.inputId.path,
    );
    if (result.registry == null) {
      for (final d in result.diagnostics) {
        log.severe(d);
      }
      throw StateError('topics.yaml is not a topic-codegen@v1 document');
    }
    await buildStep.writeAsString(
      buildStep.allowedOutputs.single,
      result.registry!,
    );
  }
}
