// Stand-in for flutter-binding@v1's bus provider (experiment only).
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

/// The bus of a widget subtree, reached by explicit reference (Spec §3.1;
/// Guide §6.4).
final class BusProvider extends StatefulWidget {
  /// Provides [bus] to [child] and owns it: shuts it down when disposed.
  const BusProvider({super.key, required this.bus, required this.child})
      : ownsBus = true;

  /// Provides [bus] to [child] without owning it.
  const BusProvider.value({super.key, required this.bus, required this.child})
      : ownsBus = false;

  final Bus bus;
  final Widget child;
  final bool ownsBus;

  /// The bus of the nearest enclosing BusProvider; registers a dependency.
  static Bus of(BuildContext context) {
    final Bus? bus = maybeOf(context);
    if (bus == null) {
      throw FlutterError(
          'BusProvider.of() was called with a context that has no BusProvider above it.');
    }
    return bus;
  }

  /// Like [of], null when there is no BusProvider above [context].
  static Bus? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BusScope>()?.bus;

  @override
  State<BusProvider> createState() => _BusProviderState();
}

final class _BusProviderState extends State<BusProvider> {
  @override
  void didUpdateWidget(BusProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownsBus && !identical(oldWidget.bus, widget.bus)) {
      oldWidget.bus.shutdown();
    }
  }

  @override
  void dispose() {
    if (widget.ownsBus) widget.bus.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _BusScope(bus: widget.bus, child: widget.child);
}

final class _BusScope extends InheritedWidget {
  const _BusScope({required this.bus, required super.child});

  final Bus bus;

  @override
  bool updateShouldNotify(_BusScope oldWidget) => !identical(bus, oldWidget.bus);
}
