import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

const LintCode flagCode = LintCode('flag_rule', 'message v1: {0}.', severity: DiagnosticSeverity.WARNING);
const LintCode otherCode = LintCode('other_rule', 'other rule: {0}.', severity: DiagnosticSeverity.WARNING);

const Set<String> flagged = <String>{'flagMe'};

class FlagRule extends AnalysisRule {
  FlagRule(this.code) : super(name: code.lowerCaseName, description: code.problemMessage);

  final LintCode code;

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addTopLevelVariableDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final VariableDeclaration v in node.variables.variables) {
      if (flagged.contains(v.name.lexeme)) rule.reportAtToken(v.name, arguments: <Object>[v.name.lexeme]);
    }
  }
}
