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
  String get name => 'wl_lint_pinned';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(_Rule());
  }
}

class _Rule extends AnalysisRule {
  static final LintCode code = LintCode('no_global_bus_pinned', 'Global Bus accessor.');

  _Rule() : super(name: 'no_global_bus_pinned', description: 'Flags Bus.instance.');

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
