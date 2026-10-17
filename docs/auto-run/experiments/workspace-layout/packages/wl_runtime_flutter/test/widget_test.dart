import 'package:flutter_test/flutter_test.dart';
import 'package:wl_runtime_flutter/wl_runtime_flutter.dart';

void main() {
  testWidgets('renders the seeded topic', (tester) async {
    await tester.pumpWidget(topicText());
    expect(find.text('a.b'), findsOneWidget);
  });
}
