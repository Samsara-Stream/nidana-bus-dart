// Expected to FAIL: a timer the bus owns is still pending when the test body
// ends, because nothing shut the bus down before the binding verified its
// invariants (an addTearDown would run too late).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_source_widget/scheduler.dart';

void main() {
  testWidgets('a grace timer still pending at the end of the body', (tester) async {
    final prov = RealTimeProvider();
    final grace = prov.zone.run(() => Timer(const Duration(milliseconds: 100), () {}));
    addTearDown(grace.cancel);
    await tester.pumpWidget(const SizedBox());
  });
}
