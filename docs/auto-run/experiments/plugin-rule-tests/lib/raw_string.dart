// A probe rule shaped as nidana.tooling.lint's plan proposes: recognition and
// the decision are pure functions of resolved nodes, returning a Finding
// value; the visitor is the only code that reports (experiment only).
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Where to report and with which arguments.
final class Finding {
  const Finding(this.node, this.arguments);
  final AstNode node;
  final List<Object> arguments;
}

bool isNidana(Element? element, String package, String name) {
  if (element == null || element.name != name) return false;
  final Uri? uri = element.library?.uri;
  return uri != null && uri.scheme == 'package' && uri.pathSegments.first == package;
}

Expression? namedArgument(ArgumentList arguments, String name) {
  for (final Argument a in arguments.arguments) {
    if (a is NamedArgument && a.name.lexeme == name) return a.argumentExpression;
  }
  return null;
}

bool isStaticFieldInitializer(Expression node) {
  final AstNode? declaration = node.parent;
  if (declaration is! VariableDeclaration || declaration.initializer != node) return false;
  final AstNode? fields = declaration.parent?.parent;
  return fields is FieldDeclaration && fields.isStatic;
}

/// The pure decision: a finding for a topic creation named by a literal
/// outside a static field initializer, else null.
Finding? decideRawString(InstanceCreationExpression node) {
  final InterfaceElement? cls = node.constructorName.element?.enclosingElement;
  if (!const <String>{'StateTopic', 'EventTopic', 'ReplayTopic'}
      .any((String n) => isNidana(cls, 'nidana_dart_contracts', n))) {
    return null;
  }
  final Expression? name = namedArgument(node.argumentList, 'name');
  if (name is! StringLiteral || isStaticFieldInitializer(node)) return null;
  return Finding(name, <Object>[name.toSource()]);
}

const LintCode rawStringTopic = LintCode(
  'raw_string_topic',
  'Topic name {0} is a string literal outside a registry.',
  correctionMessage: 'Declare the topic once as a static field of a registry class, and refer to that field.',
  severity: DiagnosticSeverity.WARNING,
);

final class RawStringTopic extends AnalysisRule {
  RawStringTopic() : super(name: 'raw_string_topic', description: rawStringTopic.problemMessage);

  @override
  LintCode get diagnosticCode => rawStringTopic;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (context.isInTestDirectory) return;
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final Finding? f = decideRawString(node);
    if (f != null) rule.reportAtNode(f.node, arguments: f.arguments);
  }
}
