// Stand-in for flutter-binding@v1's page-scope binding and page publisher
// (experiment only).
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

import 'bus_provider.dart';

/// A page's scope (Spec §7.1, §7.2) and its publisher (Spec §2.4).
final class PageScope extends StatefulWidget {
  PageScope({
    super.key,
    this.route,
    List<Topology> topologies = const <Topology>[],
    Set<StateTopic<Object?>> writes = const <StateTopic<Object?>>{},
    required this.child,
  })  : topologies = List<Topology>.unmodifiable(topologies),
        writes = Set<StateTopic<Object?>>.unmodifiable(writes) {
    for (final Topology t in this.topologies) {
      if (t.scope != Scope.page) {
        throw ArgumentError.value(t.topologyId, 'topologies', 'is not PAGE-scoped');
      }
    }
  }

  final String? route;
  final List<Topology> topologies;
  final Set<StateTopic<Object?>> writes;
  final Widget child;

  /// The publisher of the nearest enclosing PageScope.
  static Publisher publisherOf(BuildContext context) {
    final _PageScopeMarker? marker =
        context.getInheritedWidgetOfExactType<_PageScopeMarker>();
    if (marker == null) {
      throw StateError('PageScope.publisherOf() found no PageScope above the context');
    }
    return marker.publisher;
  }

  @override
  State<PageScope> createState() => _PageScopeState();
}

/// Mounted holders per topology id, per bus.
final Expando<Map<String, ({TopologyHandle handle, int holders})>> _held =
    Expando<Map<String, ({TopologyHandle handle, int holders})>>();

void _acquire(Bus bus, Topology t) {
  final Map<String, ({TopologyHandle handle, int holders})> held =
      _held[bus] ??= <String, ({TopologyHandle handle, int holders})>{};
  final TopologyHandle handle = bus.activate(t);
  final int holders = held[t.topologyId]?.holders ?? 0;
  held[t.topologyId] = (handle: handle, holders: holders + 1);
}

void _release(Bus bus, Topology t) {
  final Map<String, ({TopologyHandle handle, int holders})>? held = _held[bus];
  final ({TopologyHandle handle, int holders})? h = held?[t.topologyId];
  if (held == null || h == null) return;
  if (h.holders > 1) {
    held[t.topologyId] = (handle: h.handle, holders: h.holders - 1);
  } else {
    held.remove(t.topologyId);
    h.handle.deactivate();
  }
}

String _routeOf(BuildContext context, String? explicit) {
  if (explicit != null) return explicit;
  final RouteSettings? settings = ModalRoute.of(context)?.settings;
  final Object? arguments = settings?.arguments;
  if (arguments is NavigationEntry) return arguments.state.route.path;
  final String name = (settings?.name ?? '').replaceFirst(RegExp('^/+'), '');
  if (name.isNotEmpty) return name;
  throw StateError('PageScope has no route: give it one, or put it under a named route');
}

final class _PageScopeState extends State<PageScope> {
  Bus? _bus;
  Publisher? _publisher;
  final List<Topology> _acquired = <Topology>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bus != null) return; // binds once
    final Bus bus = BusProvider.of(context);
    final String route = _routeOf(context, widget.route);
    try {
      for (final Topology t in widget.topologies) {
        _acquire(bus, t);
        _acquired.add(t);
      }
      _publisher = bus.publisher(PageSource(route), writes: widget.writes, scope: Scope.page);
    } catch (_) {
      for (final Topology t in _acquired.reversed) {
        _release(bus, t);
      }
      _acquired.clear();
      rethrow;
    }
    _bus = bus;
  }

  @override
  void dispose() {
    final Bus? bus = _bus;
    _publisher?.dispose();
    if (bus != null) {
      for (final Topology t in _acquired.reversed) {
        _release(bus, t);
      }
    }
    _acquired.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Publisher? p = _publisher;
    if (p == null) return const SizedBox.shrink();
    return _PageScopeMarker(publisher: p, child: widget.child);
  }
}

final class _PageScopeMarker extends InheritedWidget {
  const _PageScopeMarker({required this.publisher, required super.child});

  final Publisher publisher;

  @override
  bool updateShouldNotify(_PageScopeMarker oldWidget) =>
      !identical(publisher, oldWidget.publisher);
}
