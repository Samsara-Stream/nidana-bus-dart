import 'package:wl_runtime/wl_runtime.dart';

Bus appBus() => Bus.instance;

// Deliberate raw type: the included root strict modes must flag it.
List rawList() => <int>[];
