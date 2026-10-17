import 'package:build/build.dart';

import 'src/generate.dart';

Builder topicsBuilder(BuilderOptions options) => _TopicsBuilder();

class _TopicsBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '.topics.yaml': ['.topics.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final source = await buildStep.readAsString(buildStep.inputId);
    await buildStep.writeAsString(buildStep.allowedOutputs.single, generateTopics(source));
  }
}
