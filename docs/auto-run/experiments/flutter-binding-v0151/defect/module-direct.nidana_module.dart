// Stand-in for flutter-binding@v2's module wrapper widget (experiment only):
// a module scope reference held by a widget, from its mount to its unmount
// (Spec §7.3's Flutter row, Appendix A.8; Guide Appendix B.3).
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

import 'bus_provider.dart';

/// Holds one reference of a module scope while it is mounted.
final class NidanaModule extends StatefulWidget {
  NidanaModule({
    super.key,
    required this.moduleId,
    required List<Topology> topologies,
    this.gracePeriod,
    required this.child,
  }) : topologies = List<Topology>.unmodifiable(topologies) {
    if (moduleId.isEmpty) {
      throw ArgumentError.value(moduleId, 'moduleId', 'is empty');
    }
    if (this.topologies.isEmpty) {
      throw ArgumentError.value(topologies, 'topologies', 'is empty');
    }
    for (final Topology t in this.topologies) {
      if (t.scope != Scope.module) {
        throw ArgumentError.value(t.topologyId, 'topologies', 'is not MODULE-scoped');
      }
    }
    final Duration? grace = gracePeriod;
    if (grace != null && grace.isNegative) {
      throw ArgumentError.value(grace, 'gracePeriod', 'is negative');
    }
  }

  final String moduleId;
  final List<Topology> topologies;
  final Duration? gracePeriod;
  final Widget child;

  @override
  State<NidanaModule> createState() => _NidanaModuleState();
}

final class _NidanaModuleState extends State<NidanaModule> {
  Bus? _bus;
  ModuleReference? _reference;
  final List<TopologyHandle> _handles = <TopologyHandle>[]; // seeded defect: no module scope

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bus != null) return; // binds once
    final Bus bus = BusProvider.of(context);
    for (final Topology t in widget.topologies) {
      _handles.add(bus.activate(t));
    }
    _bus = bus;
  }

  @override
  void dispose() {
    for (final TopologyHandle h in _handles.reversed) {
      h.deactivate();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
