/// Stand-in for `nidana_dart_lint`'s entry point (experiment only): the
/// analysis server imports `package:nidana_dart_lint/main.dart` and reads the
/// top-level [plugin] (ADR-002 item 3).
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules.dart';

final plugin = NidanaLintPlugin();

final class NidanaLintPlugin extends Plugin {
  @override
  String get name => 'nidana_dart_lint';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(RawStringTopic())
      ..registerWarningRule(GlobalBusAccessor())
      ..registerWarningRule(ExplicitTopicTypeArguments())
      ..registerWarningRule(UnflaggedSensitiveTopic());
  }
}
