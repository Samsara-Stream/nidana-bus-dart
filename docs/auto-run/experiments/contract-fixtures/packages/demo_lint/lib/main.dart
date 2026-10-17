// A one-rule analysis server plugin: flags a global `Bus.instance` accessor,
// the v1 lint Guide Appendix C.5 lists for Spec §3.1.
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

final plugin = ProbePlugin();

class ProbePlugin extends Plugin {
  @override
  String get name => 'demo_lint';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(NoGlobalBus());
  }
}

class NoGlobalBus extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_global_bus',
    'A global Bus accessor breaks Spec §3.1.',
    correctionMessage: 'Pass a Bus reference explicitly.',
  );

  NoGlobalBus() : super(name: 'no_global_bus', description: 'Flags Bus.instance.');

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addPrefixedIdentifier(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'Bus' && node.identifier.name == 'instance') {
      rule.reportAtNode(node);
    }
  }
}
