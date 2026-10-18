// analyzer_testing under plain package:test: one AnalysisRuleTest instance per
// test, its setUp and tearDown called from package:test's hooks.
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:plugin_rule_tests/raw_string.dart';
import 'package:test/test.dart';

final class _Harness extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = RawStringTopic();
    // newPackage registers a package in the package config super.setUp()
    // writes, so the stand-ins come first.
    // A stand-in library carrying the package and element names recognition
    // matches (nidana-checks@v1 Recognition), declared under lib/src/.
    newPackage('nidana_dart_contracts')
      ..addFile('lib/nidana_dart_contracts.dart', "export 'src/topic.dart';")
      ..addFile('lib/src/topic.dart', '''
final class EventTopic<T> {
  const EventTopic({required this.name});
  final String name;
}
''');
    // A same-named class of another package (G3).
    newPackage('other')
      ..addFile('lib/other.dart', '''
final class EventTopic<T> {
  const EventTopic({required this.name});
  final String name;
}
''');
    super.setUp();
  }

  @override
  String get analysisRule => 'raw_string_topic';
}

final class _Creations extends RecursiveAstVisitor<void> {
  final List<InstanceCreationExpression> found = <InstanceCreationExpression>[];
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    found.add(node);
    super.visitInstanceCreationExpression(node);
  }
}

const String _source = r'''
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:other/other.dart' as other;

abstract final class Topics {
  static const EventTopic<int> ok = EventTopic<int>(name: 'a.ok');
}

final EventTopic<int> top = EventTopic<int>(name: 'a.top');
final other.EventTopic<int> notOurs = other.EventTopic<int>(name: 'b.top');
''';

void main() {
  late _Harness t;
  setUp(() {
    t = _Harness();
    t.setUp();
  });
  tearDown(() => t.tearDown());

  test('Q1 the rule reports through assertDiagnostics, with its message', () async {
    final int at = _source.indexOf("'a.top'");
    await t.assertDiagnostics(_source, [
      t.lint(at, 7, messageContainsAll: <String>["Topic name 'a.top' is a string literal outside a registry."]),
    ]);
  });

  test('Q2 the decision is a pure function over a resolved node', () async {
    t.newFile(t.testFile.path, _source);
    final result = await t.resolveFile(t.testFile.path);
    final _Creations v = _Creations();
    result.unit.accept(v);
    final List<String?> decided = <String?>[
      for (final InstanceCreationExpression c in v.found) decideRawString(c)?.arguments.single as String?,
    ];
    expect(decided, <String?>[null, "'a.top'", null]);
  });

  test('Q3 nothing is reported in a test directory', () async {
    final String path = '${t.testPackageRootPath}/test/topics_test.dart';
    t.newFile(path, _source);
    await t.assertNoDiagnosticsInFile(path);
  });
}
