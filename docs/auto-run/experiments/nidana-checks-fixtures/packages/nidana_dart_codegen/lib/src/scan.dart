// Stand-in of the workspace scan command of nidana-checks@v1 (experiment
// only): `scan [--graph <graph>] <package>...`.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:path/path.dart' as p;

import 'claims.dart';

const String usage = 'usage: nidana_dart_codegen:scan [--graph <graph>] <package>...';
const Set<String> testDirectories = <String>{'test', 'integration_test', 'test_driver', 'testing'};

final class UsageError implements Exception {
  UsageError(this.message);
  final String message;
}

String escapeField(String s) => s.replaceAll(r'\', r'\\').replaceAll('|', r'\|').replaceAll('\n', r'\n');

String line(String severity, String code, String location, String message) =>
    <String>[severity, code, location, message].map(escapeField).join('|');

String _variantClass(TopicVariant v) => switch (v) {
      TopicVariant.state => 'StateTopic',
      TopicVariant.event => 'EventTopic',
      TopicVariant.replay => 'ReplayTopic',
    };

String _count(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';

Future<int> runScan(List<String> args, {required IOSink out, required IOSink err}) async {
  String? graphPath;
  final List<String> packages = <String>[];
  try {
    for (int i = 0; i < args.length; i++) {
      final String a = args[i];
      if (a == '--graph') {
        if (i + 1 >= args.length || graphPath != null) throw UsageError('--graph takes one graph document');
        graphPath = args[++i];
      } else if (a.startsWith('-')) {
        throw UsageError('unknown option $a');
      } else {
        packages.add(a);
      }
    }
    if (packages.isEmpty) throw UsageError('no package given');
    for (final String pkg in packages) {
      if (!File(p.join(pkg, 'pubspec.yaml')).existsSync()) throw UsageError('$pkg is not a package root');
    }
  } on UsageError catch (e) {
    err
      ..writeln(e.message)
      ..writeln(usage);
    return 2;
  }

  List<TopologyDefinition> topologies = const <TopologyDefinition>[];
  if (graphPath != null) {
    try {
      topologies = decodeTopologyGraph(jsonDecode(File(graphPath).readAsStringSync())).topologies;
    } on Object catch (e) {
      err.writeln('$graphPath: $e');
      return 2;
    }
  }

  final String cwd = p.normalize(p.absolute(Directory.current.path));
  String siteOf(String path, int offset, ResolvedUnitResult unit) {
    final location = unit.lineInfo.getLocation(offset);
    final String shown = p.isWithin(cwd, path) ? p.relative(path, from: cwd) : path;
    return '${p.posix.joinAll(p.split(shown))}:${location.lineNumber}:${location.columnNumber}';
  }

  final List<String> roots = <String>[for (final String pkg in packages) p.normalize(p.absolute(pkg))];
  final AnalysisContextCollection collection = AnalysisContextCollection(includedPaths: roots);
  final Set<String> files = <String>{};
  for (final AnalysisContext context in collection.contexts) {
    for (final String file in context.contextRoot.analyzedFiles()) {
      if (!file.endsWith('.dart')) continue;
      final String? root = roots.where((String r) => p.isWithin(r, file)).firstOrNull;
      if (root == null) continue;
      final String first = p.split(p.relative(file, from: root)).first;
      if (testDirectories.contains(first)) continue;
      files.add(file);
    }
  }

  late SourceWalk walk;
  ResolvedUnitResult? current;
  walk = SourceWalk((String path, int offset) => siteOf(path, offset, current!));
  for (final String file in files.toList()..sort()) {
    final AnalysisContext context = collection.contextFor(file);
    final Object unit = await context.currentSession.getResolvedUnit(file);
    if (unit is! ResolvedUnitResult || !unit.exists) continue;
    current = unit;
    await walk.walk(unit);
  }

  final List<String> errors = <String>[];
  for (final TopicNameCollision c in findTopicNameCollisions(walk.declarations)) {
    final String sites = c.declarations
        .map((TopicDeclaration d) => '${d.site} (${_variantClass(d.topic.variant)}<${d.topic.typeName}>)')
        .join(', ');
    errors.add(line('error', 'topic_name_collision', c.declarations.first.site,
        "Topic name '${c.name}' is declared ${c.declarations.length} times: $sites."));
  }

  final TopologyGraph graph = TopologyGraph(
    topologies: topologies,
    claims: <ShellClaim>[for (final FoundClaim f in walk.claims) f.claim],
  );

  String claimWriter(MessageSource source, TopicRef topic, Scope? scope, Map<String, List<String>> queues) {
    if (source is TopologySource) return source.toString();
    final String key = '$source|${topic.name}|${scope?.name}';
    final List<String> queue = queues.putIfAbsent(key, () {
      return <String>[
        for (final FoundClaim f in walk.claims)
          if (f.claim.source == source && f.claim.writes.contains(topic) && (scope == null || f.claim.scope == scope))
            f.site,
      ]..sort();
    });
    final String site = queue.length > 1 ? queue.removeAt(0) : queue.first;
    final String rendered = source.toString();
    // A stand-in source is named after its site: render it once.
    if (rendered.substring(rendered.indexOf(':') + 1) == site) return rendered;
    return '$rendered at $site';
  }

  for (final TopologyFinding finding in analyzeTopologyGraph(graph)) {
    final Map<String, List<String>> queues = <String, List<String>>{};
    switch (finding) {
      case TopologyCycle():
        errors.add(line('error', 'topology_cycle', '',
            'Topologies ${finding.topologyIds.join(', ')} form a cycle through ${finding.topics.map((TopicRef t) => t.name).toSet().join(', ')}.'));
      case SelfReference():
        errors.add(line('error', 'self_reference', '',
            "Topology '${finding.topologyId}' reads '${finding.topic.name}', which it writes, through no state-bearing edge (${finding.edges.length == 1 ? 'edge' : 'edges'} ${finding.edges.join(', ')})."));
      case WriterConflict():
        final String writers =
            finding.writers.map((MessageSource s) => claimWriter(s, finding.topic, null, queues)).join(', ');
        errors.add(line('error', 'writer_conflict', '',
            "State topic '${finding.topic.name}' has ${_count(finding.writers.length, 'writer')}: $writers."));
      case ScopeViolation():
        final String owner = claimWriter(finding.owner, finding.topic, finding.ownerScope, queues);
        errors.add(line('error', 'scope_violation', '',
            "State topic '${finding.topic.name}' is owned by $owner with scope ${finding.ownerScope.name} and read by topology:${finding.readerId} with scope ${finding.readerScope.name}; an owner's scope must be at least as long as its readers'."));
    }
  }

  final List<Unresolved> warnings = walk.unresolved.toList()
    ..sort((Unresolved a, Unresolved b) => _compareSites(a.site, b.site));
  for (final String e in errors) {
    out.writeln(e);
  }
  for (final Unresolved w in warnings) {
    out.writeln(line('warning', w.code, w.site, w.message));
  }
  return errors.isEmpty ? 0 : 1;
}

int _compareSites(String a, String b) {
  (String, int, int) parts(String s) {
    final List<String> x = s.split(':');
    final int col = int.parse(x.removeLast());
    final int ln = int.parse(x.removeLast());
    return (x.join(':'), ln, col);
  }

  final (String pa, int la, int ca) = parts(a);
  final (String pb, int lb, int cb) = parts(b);
  final int byPath = pa.compareTo(pb);
  if (byPath != 0) return byPath;
  return la != lb ? la.compareTo(lb) : ca.compareTo(cb);
}
