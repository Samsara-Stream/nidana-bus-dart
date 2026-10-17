// The same rule as plugin_probe, written for custom_lint (Guide Appendix C.2
// names custom_lint for nidana_dart_lint).
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _Probe();

class _Probe extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [NoGlobalBus()];
}

class NoGlobalBus extends DartLintRule {
  NoGlobalBus() : super(code: _code);
  static const _code = LintCode(name: 'no_global_bus', problemMessage: 'A global Bus accessor breaks Spec §3.1.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    context.registry.addPrefixedIdentifier((node) {
      if (node.prefix.name == 'Bus' && node.identifier.name == 'instance') {
        reporter.atNode(node, _code);
      }
    });
  }
}
