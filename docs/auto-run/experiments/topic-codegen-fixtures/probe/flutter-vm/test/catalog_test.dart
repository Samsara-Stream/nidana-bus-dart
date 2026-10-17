import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vm_probe/page_topology.dart';

void main() {
  test('loads under the Flutter tester', () {
    expect(pageTopologyId, 'payment-form');
    expect(flutterLoaded, isTrue);
  });
}
