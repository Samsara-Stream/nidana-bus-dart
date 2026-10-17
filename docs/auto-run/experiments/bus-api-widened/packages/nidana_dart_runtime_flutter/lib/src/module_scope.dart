// Stand-in for flutter-binding@v1's module-scope binding (experiment only).
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

List<String> _segments(String path) =>
    path.split('/').where((String s) => s.isNotEmpty).toList();

/// One module's route subtree (Spec §7.3).
@immutable
final class ModuleRoutes {
  ModuleRoutes({
    required this.moduleId,
    required this.prefix,
    required List<Topology> topologies,
    this.gracePeriod,
  })  : topologies = List<Topology>.unmodifiable(topologies),
        _prefix = _segments(prefix) {
    if (_prefix.isEmpty) {
      throw ArgumentError.value(prefix, 'prefix', 'has no segment');
    }
  }

  final String moduleId;
  final String prefix;
  final List<Topology> topologies;
  final Duration? gracePeriod;
  final List<String> _prefix;

  bool matches(String path) {
    final List<String> p = _segments(path);
    if (p.length < _prefix.length) return false;
    for (var i = 0; i < _prefix.length; i++) {
      if (p[i] != _prefix[i]) return false;
    }
    return true;
  }
}

/// Binds module scopes to the routes of the Navigator it observes.
final class ModuleScopeObserver extends NavigatorObserver {
  ModuleScopeObserver(this.bus, List<ModuleRoutes> modules)
      : _modules = List<ModuleRoutes>.unmodifiable(modules),
        scopes = List<ModuleScope>.unmodifiable(<ModuleScope>[
          for (final ModuleRoutes m in modules)
            bus.module(m.moduleId, m.topologies, gracePeriod: m.gracePeriod),
        ]);

  final Bus bus;
  final List<ModuleRoutes> _modules;
  final List<ModuleScope> scopes;
  final Map<Route<dynamic>, List<ModuleReference>> _held =
      <Route<dynamic>, List<ModuleReference>>{};
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// The path [route] is matched by.
  static String? pathOf(Route<dynamic> route) {
    final Object? arguments = route.settings.arguments;
    if (arguments is NavigationEntry) return arguments.state.route.path;
    return route.settings.name;
  }

  void _acquire(Route<dynamic> route) {
    if (_disposed || bus.lifecycle == BusLifecycle.shutDown) return;
    final String? path = pathOf(route);
    if (path == null) return;
    final List<ModuleReference> refs = <ModuleReference>[];
    for (var i = 0; i < _modules.length; i++) {
      if (!_modules[i].matches(path)) continue;
      try {
        refs.add(scopes[i].acquire());
      } catch (error, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'nidana_dart_runtime_flutter',
          context: ErrorDescription('while acquiring module ${_modules[i].moduleId} for $path'),
        ));
      }
    }
    if (refs.isNotEmpty) (_held[route] ??= <ModuleReference>[]).addAll(refs);
  }

  void _release(Route<dynamic>? route) {
    final List<ModuleReference>? refs = _held.remove(route);
    if (refs == null) return;
    for (final ModuleReference r in refs) {
      r.release();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _acquire(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _release(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _release(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _acquire(newRoute);
    _release(oldRoute);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final Route<dynamic> r in List<Route<dynamic>>.of(_held.keys)) {
      _release(r);
    }
  }
}
