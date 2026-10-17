// Stand-in of the source walk nidana-checks@v1 defines (experiment only):
// topic declarations and claim sites in application code, recognized by
// package and element name, resolved statically or reported unresolved.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

const contractsPackage = 'nidana_dart_contracts';
const runtimePackage = 'nidana_dart_runtime';
const navigationPackage = 'nidana_dart_navigation';
const flutterPackage = 'nidana_dart_runtime_flutter';

bool isNidana(Element? element, String package, String name) {
  if (element == null || element.name != name) return false;
  final Uri? uri = element.library?.uri;
  return uri != null && uri.scheme == 'package' && uri.pathSegments.isNotEmpty && uri.pathSegments.first == package;
}

bool isNidanaClassOrSubclass(InterfaceElement? element, String package, String name) {
  if (element == null) return false;
  if (isNidana(element, package, name)) return true;
  return element.allSupertypes.any((InterfaceType t) => isNidana(t.element, package, name));
}

Expression? namedArgument(ArgumentList arguments, String name) {
  for (final Argument a in arguments.arguments) {
    if (a is NamedArgument && a.name.lexeme == name) return a.argumentExpression;
  }
  return null;
}

Expression? firstPositional(ArgumentList arguments) {
  for (final Argument a in arguments.arguments) {
    if (a is Expression) return a;
  }
  return null;
}

/// The string a literal holds when it has no interpolation, else null.
String? literalValue(Expression? e) => e is StringLiteral ? e.stringValue : null;

const _variantClasses = <String, TopicVariant>{
  'StateTopic': TopicVariant.state,
  'EventTopic': TopicVariant.event,
  'ReplayTopic': TopicVariant.replay,
};

/// The variant of a topic creation (StateTopic, EventTopic, ReplayTopic of
/// nidana_dart_contracts), or null.
TopicVariant? variantOf(InstanceCreationExpression node) {
  final InterfaceElement? cls = node.constructorName.element?.enclosingElement;
  for (final MapEntry<String, TopicVariant> e in _variantClasses.entries) {
    if (isNidana(cls, contractsPackage, e.key)) return e.value;
  }
  return null;
}

/// A source site, rendered `{path}:{line}:{column}`.
typedef SiteOf = String Function(String path, int offset);

final class FoundClaim {
  FoundClaim(this.claim, this.site);
  final ShellClaim claim;
  final String site;
}

final class Unresolved {
  Unresolved(this.code, this.site, this.message);
  final String code;
  final String site;
  final String message;
}

const String _unresolvedWrites =
    "This claim's write set is not statically resolvable; the runtime check covers it.";
const String _unresolvedScope = "This claim's scope is not statically resolvable; the runtime check covers it.";
const String _unresolvedName = "This topic's name is not a string literal; the runtime check covers it.";

final class SourceWalk {
  SourceWalk(this.siteOf);
  final SiteOf siteOf;
  final List<TopicDeclaration> declarations = <TopicDeclaration>[];
  final List<FoundClaim> claims = <FoundClaim>[];
  final List<Unresolved> unresolved = <Unresolved>[];
  final Map<Element, Object> _declarationCache = <Element, Object>{};

  Future<void> walk(ResolvedUnitResult unit) async {
    final _Collector c = _Collector();
    unit.unit.accept(c);
    for (final VariableDeclaration v in c.declarations) {
      final InstanceCreationExpression creation = v.initializer! as InstanceCreationExpression;
      final TopicVariant variant = variantOf(creation)!;
      final String site = siteOf(unit.path, v.name.offset);
      final String? name = literalValue(namedArgument(creation.argumentList, 'name'));
      if (name == null) {
        unresolved.add(Unresolved('unresolved_topic_name', site, _unresolvedName));
        continue;
      }
      final DartType valueType = (creation.staticType! as InterfaceType).typeArguments.first;
      declarations.add(TopicDeclaration(
        topic: TopicRef(name: name, variant: variant, typeName: valueType.getDisplayString()),
        site: site,
      ));
    }
    for (final AstNode site in c.claimSites) {
      await _claim(unit, site);
    }
  }

  Future<void> _claim(ResolvedUnitResult unit, AstNode node) async {
    late final String site;
    late final Set<TopicRef>? writes;
    late final Scope? scope;
    late final MessageSource source;
    if (node is MethodInvocation) {
      site = siteOf(unit.path, node.methodName.offset);
      final Expression? writesArg = namedArgument(node.argumentList, 'writes');
      if (writesArg == null) return; // no claim
      writes = await _writeSet(unit.session, writesArg);
      final Expression? scopeArg = namedArgument(node.argumentList, 'scope');
      scope = scopeArg == null ? Scope.application : _scope(scopeArg);
      source = await _source(unit.session, firstPositional(node.argumentList), site);
    } else {
      final InstanceCreationExpression creation = node as InstanceCreationExpression;
      site = siteOf(unit.path, creation.constructorName.offset);
      final InterfaceElement? cls = creation.constructorName.element?.enclosingElement;
      if (isNidana(cls, flutterPackage, 'PageScope')) {
        final Expression? writesArg = namedArgument(creation.argumentList, 'writes');
        if (writesArg == null) return;
        writes = await _writeSet(unit.session, writesArg);
        scope = Scope.page;
        final Expression? route = namedArgument(creation.argumentList, 'route');
        final String? literal = literalValue(route);
        source = PageSource(literal != null && literal.isNotEmpty ? literal : site);
      } else {
        // NavigationExecutor or FlutterNavigationExecutor: navigation-api@v1 G19.
        writes = <TopicRef>{
          const TopicRef(name: 'nav.current-route', variant: TopicVariant.state, typeName: 'RouteState'),
        };
        scope = Scope.application;
        final Expression? nameArg = namedArgument(creation.argumentList, 'name');
        final String fallback = isNidana(cls, navigationPackage, 'NavigationExecutor') ? 'navigation' : 'flutter-navigation';
        final String? literal = nameArg == null ? fallback : literalValue(nameArg);
        source = ExecutorSource(literal != null && literal.isNotEmpty ? literal : site);
      }
    }
    if (writes == null) {
      unresolved.add(Unresolved('unresolved_claim', site, _unresolvedWrites));
      return;
    }
    if (writes.isEmpty) return;
    if (scope == null) {
      unresolved.add(Unresolved('unresolved_claim', site, _unresolvedScope));
      return;
    }
    claims.add(FoundClaim(ShellClaim(source: source, scope: scope, writes: writes), site));
  }

  Scope? _scope(Expression e) {
    final Element? element = switch (e) {
      PrefixedIdentifier() => e.identifier.element,
      PropertyAccess() => e.propertyName.element,
      _ => null,
    };
    final Element? owner = element?.enclosingElement;
    if (!isNidana(owner, contractsPackage, 'Scope')) return null;
    for (final Scope s in Scope.values) {
      if (s.name == element!.name) return s;
    }
    return null;
  }

  /// The variable a reference names: a top-level variable or a static field.
  PropertyInducingElement? _variableOf(Expression e) {
    final Element? element = switch (e) {
      SimpleIdentifier() => e.element,
      PrefixedIdentifier() => e.identifier.element,
      PropertyAccess() => e.propertyName.element,
      _ => null,
    };
    if (element is! GetterElement) return null;
    final PropertyInducingElement variable = element.variable;
    if (variable is TopLevelVariableElement) return variable;
    if (variable is FieldElement && variable.isStatic) return variable;
    return null;
  }

  Future<Expression?> _initializerOf(AnalysisSession session, PropertyInducingElement variable) async {
    final Object cached = _declarationCache[variable] ??= await () async {
      final SomeResolvedLibraryResult lib = await session.getResolvedLibraryByElement(variable.library);
      if (lib is! ResolvedLibraryResult) return false;
      final AstNode? node = lib.getFragmentDeclaration(variable.firstFragment)?.node;
      return node is VariableDeclaration && node.initializer != null ? node.initializer! : false;
    }();
    return cached is Expression ? cached : null;
  }

  Future<Set<TopicRef>?> _writeSet(AnalysisSession session, Expression e) async {
    if (e is! SetOrMapLiteral || !e.isSet) return null;
    final Set<TopicRef> refs = <TopicRef>{};
    for (final CollectionElement element in e.elements) {
      if (element is! Expression) return null;
      final PropertyInducingElement? variable = _variableOf(element);
      if (variable == null) return null;
      final Expression? init = await _initializerOf(session, variable);
      if (init is! InstanceCreationExpression || variantOf(init) != TopicVariant.state) return null;
      final String? name = literalValue(namedArgument(init.argumentList, 'name'));
      if (name == null) return null;
      final DartType valueType = (init.staticType! as InterfaceType).typeArguments.first;
      refs.add(TopicRef(name: name, variant: TopicVariant.state, typeName: valueType.getDisplayString()));
    }
    return refs;
  }

  static const _sourceClasses = <String>{'ServiceSource', 'PageSource', 'ExecutorSource'};

  MessageSource _make(String cls, String name) => switch (cls) {
        'PageSource' => PageSource(name),
        'ExecutorSource' => ExecutorSource(name),
        _ => ServiceSource(name),
      };

  String? _sourceClass(InstanceCreationExpression c) {
    final InterfaceElement? cls = c.constructorName.element?.enclosingElement;
    for (final String s in _sourceClasses) {
      if (isNidana(cls, contractsPackage, s)) return s;
    }
    return null;
  }

  Future<MessageSource> _source(AnalysisSession session, Expression? e, String site) async {
    Expression? creation = e;
    if (e != null && e is! InstanceCreationExpression) {
      final PropertyInducingElement? variable = _variableOf(e);
      if (variable != null && (variable.isConst || variable.isFinal)) {
        creation = await _initializerOf(session, variable);
      }
    }
    if (creation is InstanceCreationExpression) {
      final String? cls = _sourceClass(creation);
      if (cls != null) {
        final String? name = literalValue(firstPositional(creation.argumentList));
        return _make(cls, name != null && name.isNotEmpty ? name : site);
      }
    }
    return ServiceSource(site);
  }
}

final class _Collector extends RecursiveAstVisitor<void> {
  final List<VariableDeclaration> declarations = <VariableDeclaration>[];
  final List<AstNode> claimSites = <AstNode>[];

  void _variables(VariableDeclarationList list) {
    for (final VariableDeclaration v in list.variables) {
      final Expression? init = v.initializer;
      if (init is InstanceCreationExpression && variantOf(init) != null) declarations.add(v);
    }
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _variables(node.variables);
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) _variables(node.fields);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'publisher') {
      final Element? owner = node.methodName.element?.enclosingElement;
      if (owner is InterfaceElement && isNidanaClassOrSubclass(owner, runtimePackage, 'Bus')) {
        claimSites.add(node);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final InterfaceElement? cls = node.constructorName.element?.enclosingElement;
    if (isNidana(cls, flutterPackage, 'PageScope') ||
        isNidana(cls, navigationPackage, 'NavigationExecutor') ||
        isNidana(cls, flutterPackage, 'FlutterNavigationExecutor')) {
      claimSites.add(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}
