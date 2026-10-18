// Probe plugin (experiment only). run.sh edits this file and src/rule.dart
// between analyses and records whether the next `dart analyze` sees the edit.
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rule.dart';

final plugin = _Plugin();

class _Plugin extends Plugin {
  @override
  String get name => 'pr_lint';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(FlagRule(flagCode));
    // MAIN-EDIT
  }
}
