// Probe R3 for OQ-F1: GoRouter has no pop-until (Guide §3.2's BackTo needs
// one or is synthesized from pops). run.sh analyzes this file and prints the
// diagnostics; a line tagged R3 with no diagnostic compiles.
import 'package:go_router/go_router.dart';

void backTo(GoRouter router) {
  router.pop(); // R3a compiles
  router.popUntil('/a'); // R3b
}
