import 'package:flutter_test/flutter_test.dart';
import 'package:ws_ui/ws_ui.dart';
void main() {
  testWidgets('flutter member renders a pure member value', (tester) async {
    await tester.pumpWidget(answerText());
    expect(find.text('42'), findsOneWidget);
  });
}
