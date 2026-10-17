import 'package:flutter_test/flutter_test.dart';
import 'package:wl_integration/auth.topics.g.dart';

void main() {
  testWidgets('generated registry is importable', (tester) async {
    expect(topicNames, ['auth.state', 'auth.login-requested']);
  });
}
