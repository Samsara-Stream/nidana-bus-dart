// Probe plugin (experiment only). Four rules flag the same expression,
// `Bus.instance`, and differ in two inputs only:
//
//   registration   registerWarningRule or registerLintRule
//   declared code  LintCode with no severity argument (the constructor's
//                  default), or with severity: DiagnosticSeverity.WARNING
//
// warning_default is the shape of workspace-layout's stand-in rules
// (packages/wl_lint*/lib/main.dart there); warning_declared is the shape of
// nidana-checks-fixtures' stand-in rules (packages/nidana_dart_lint/lib/src/
// rules.dart there). The two lint_* rules vary the registration.

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

final plugin = _Plugin();

class _Plugin extends Plugin {
  @override
  String get name => 'ps_lint';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(_Rule(const LintCode('warning_default', 'warning rule, default severity.')))
      ..registerWarningRule(_Rule(const LintCode('warning_declared', 'warning rule, declared WARNING.',
          severity: DiagnosticSeverity.WARNING)))
      ..registerLintRule(_Rule(const LintCode('lint_default', 'lint rule, default severity.')))
      ..registerLintRule(_Rule(const LintCode('lint_declared', 'lint rule, declared WARNING.',
          severity: DiagnosticSeverity.WARNING)));
  }
}

class _Rule extends AnalysisRule {
  _Rule(this.code) : super(name: code.lowerCaseName, description: code.problemMessage);

  final LintCode code;

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
