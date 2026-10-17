// Stand-in rules of nidana-checks@v1 (experiment only). Each rule recognizes
// nidana API by package and element name (ADR-002 item 7), never by a library
// path, and reports only in application code: a library outside its
// package's test directories (RuleContext.isInTestDirectory).

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

const _contracts = 'nidana_dart_contracts';
const _runtime = 'nidana_dart_runtime';

/// Whether [element] is named [name] and declared in a library of [package].
bool isNidana(Element? element, String package, String name) {
  if (element == null || element.name != name) return false;
  final Uri? uri = element.library?.uri;
  return uri != null &&
      uri.scheme == 'package' &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == package;
}

/// Whether [element] is, or is a subclass of, the class [name] of [package].
bool isNidanaClassOrSubclass(InterfaceElement? element, String package, String name) {
  if (element == null) return false;
  if (isNidana(element, package, name)) return true;
  return element.allSupertypes.any((InterfaceType t) => isNidana(t.element, package, name));
}

const _topicClasses = <String>{'StateTopic', 'EventTopic', 'ReplayTopic'};

/// The topic class a creation constructs (StateTopic, EventTopic, ReplayTopic
/// of nidana_dart_contracts), or null.
String? topicClassOf(InstanceCreationExpression node) {
  final InterfaceElement? cls = node.constructorName.element?.enclosingElement;
  if (cls == null) return null;
  for (final String name in _topicClasses) {
    if (isNidana(cls, _contracts, name)) return name;
  }
  return null;
}

Expression? namedArgument(ArgumentList arguments, String name) {
  for (final Argument a in arguments.arguments) {
    if (a is NamedArgument && a.name.lexeme == name) return a.argumentExpression;
  }
  return null;
}

/// Whether [node] is the whole initializer of a static field.
bool isStaticFieldInitializer(Expression node) {
  final AstNode? declaration = node.parent;
  if (declaration is! VariableDeclaration || declaration.initializer != node) return false;
  final AstNode? fields = declaration.parent?.parent;
  return fields is FieldDeclaration && fields.isStatic;
}

abstract base class _NidanaRule extends AnalysisRule {
  _NidanaRule(this.code) : super(name: code.lowerCaseName, description: code.problemMessage);

  final LintCode code;

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (context.isInTestDirectory) return;
    registerApplicationCode(registry, context);
  }

  void registerApplicationCode(RuleVisitorRegistry registry, RuleContext context);
}

// ---- raw_string_topic (Spec §4.2, §4.4)

final class RawStringTopic extends _NidanaRule {
  RawStringTopic()
      : super(const LintCode(
          'raw_string_topic',
          'Topic name {0} is a string literal outside a registry.',
          correctionMessage:
              'Declare the topic once as a static field of a registry class, and refer to that field.',
          severity: DiagnosticSeverity.WARNING,
        ));

  @override
  void registerApplicationCode(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _RawStringVisitor(this));
  }
}

final class _RawStringVisitor extends SimpleAstVisitor<void> {
  _RawStringVisitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (topicClassOf(node) == null) return;
    final Expression? name = namedArgument(node.argumentList, 'name');
    if (name is! StringLiteral) return;
    if (isStaticFieldInitializer(node)) return;
    rule.reportAtNode(name, arguments: <Object>[name.toSource()]);
  }
}

// ---- global_bus_accessor (Spec §3.1; Guide C.5)

final class GlobalBusAccessor extends _NidanaRule {
  GlobalBusAccessor()
      : super(const LintCode(
          'global_bus_accessor',
          "'{0}' makes a bus reachable without an explicit reference.",
          correctionMessage:
              'Pass the Bus explicitly: as a constructor or function argument, or through BusProvider.of(context).',
          severity: DiagnosticSeverity.WARNING,
        ));

  @override
  void registerApplicationCode(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _GlobalBusVisitor(this);
    registry
      ..addTopLevelVariableDeclaration(this, visitor)
      ..addFieldDeclaration(this, visitor)
      ..addFunctionDeclaration(this, visitor)
      ..addMethodDeclaration(this, visitor);
  }
}

bool isBusType(DartType? type) {
  if (type is! InterfaceType) return false;
  return isNidanaClassOrSubclass(type.element, _runtime, 'Bus');
}

final class _GlobalBusVisitor extends SimpleAstVisitor<void> {
  _GlobalBusVisitor(this.rule);
  final AnalysisRule rule;

  void _variables(VariableDeclarationList list) {
    for (final VariableDeclaration v in list.variables) {
      if (isBusType(v.declaredFragment?.element.type)) {
        rule.reportAtToken(v.name, arguments: <Object>[v.name.lexeme]);
      }
    }
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) => _variables(node.variables);

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) _variables(node.fields);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is! CompilationUnit || !node.isGetter) return;
    if (isBusType(node.declaredFragment?.element.returnType)) {
      rule.reportAtToken(node.name, arguments: <Object>[node.name.lexeme]);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!node.isStatic || !node.isGetter) return;
    if (isBusType(node.declaredFragment?.element.returnType)) {
      rule.reportAtToken(node.name, arguments: <Object>[node.name.lexeme]);
    }
  }
}

// ---- explicit_topic_type_arguments (Spec §4.2; bus-api@v1 G40)

final class ExplicitTopicTypeArguments extends _NidanaRule {
  ExplicitTopicTypeArguments()
      : super(const LintCode(
          'explicit_topic_type_arguments',
          "Explicit type arguments on '{0}' can widen the topic's value type.",
          correctionMessage: "Remove the type arguments, so that the topic's type decides the value's type.",
          severity: DiagnosticSeverity.WARNING,
        ));

  @override
  void registerApplicationCode(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _ExplicitTypeArgumentsVisitor(this));
  }
}

final class _ExplicitTypeArgumentsVisitor extends SimpleAstVisitor<void> {
  _ExplicitTypeArgumentsVisitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final TypeArgumentList? typeArguments = node.typeArguments;
    if (typeArguments == null) return;
    final Element? method = node.methodName.element;
    final Element? owner = method?.enclosingElement;
    if (owner is! InterfaceElement) return;
    final String name = node.methodName.name;
    final bool sink = switch (name) {
      'publish' => isNidanaClassOrSubclass(owner, _runtime, 'Bus') || isNidana(owner, _runtime, 'Publisher'),
      'write' || 'reduceInto' => isNidana(owner, _contracts, 'TopologyBuilder'),
      _ => false,
    };
    if (sink) rule.reportAtNode(typeArguments, arguments: <Object>[name]);
  }
}

// ---- unflagged_sensitive_topic (Spec §9.2; Guide C.1)

final class UnflaggedSensitiveTopic extends _NidanaRule {
  UnflaggedSensitiveTopic()
      : super(const LintCode(
          'unflagged_sensitive_topic',
          "The topic type '{0}' contains the known-sensitive type '{1}', but the topic is not flagged sensitive.",
          correctionMessage: "Add 'sensitive: true' to the topic's declaration, or to its entry in topics.yaml.",
        ));

  @override
  void registerApplicationCode(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _SensitiveVisitor(this));
  }
}

const _sensitiveSuffixes = <String>['Token', 'Credential', 'Credentials', 'PaymentInfo'];

bool _annotatedSensitive(Element element) => element.metadata.annotations.any((ElementAnnotation a) {
      final Element? e = a.element;
      if (e is ConstructorElement) return e.enclosingElement.name == 'Sensitive';
      if (e is PropertyAccessorElement) {
        final DartType t = e.returnType;
        return t is InterfaceType && t.element.name == 'Sensitive';
      }
      return false;
    });

bool _namedSensitive(String? name) => name != null && _sensitiveSuffixes.any(name.endsWith);

/// The first known-sensitive type in [type], depth first: its alias, the type
/// itself, then its type arguments or record fields; null when none.
String? sensitiveTypeIn(DartType type) {
  final InstantiatedTypeAliasElement? alias = type.alias;
  if (alias != null && (_namedSensitive(alias.element.name) || _annotatedSensitive(alias.element))) {
    return alias.element.name;
  }
  if (type is InterfaceType) {
    final InterfaceElement e = type.element;
    if (_namedSensitive(e.name) || _annotatedSensitive(e)) return e.name;
    for (final DartType a in type.typeArguments) {
      final String? found = sensitiveTypeIn(a);
      if (found != null) return found;
    }
  } else if (type is RecordType) {
    for (final DartType f in <DartType>[
      for (final RecordTypePositionalField p in type.positionalFields) p.type,
      for (final RecordTypeNamedField n in type.namedFields) n.type,
    ]) {
      final String? found = sensitiveTypeIn(f);
      if (found != null) return found;
    }
  }
  return null;
}

final class _SensitiveVisitor extends SimpleAstVisitor<void> {
  _SensitiveVisitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (topicClassOf(node) == null) return;
    final DartType? created = node.staticType;
    if (created is! InterfaceType || created.typeArguments.isEmpty) return;
    final Expression? flag = namedArgument(node.argumentList, 'sensitive');
    if (flag != null && !(flag is BooleanLiteral && !flag.value)) return;
    final DartType valueType = created.typeArguments.first;
    final String? found = sensitiveTypeIn(valueType);
    if (found == null) return;
    rule.reportAtNode(node.constructorName,
        arguments: <Object>[valueType.getDisplayString(), found]);
  }
}
