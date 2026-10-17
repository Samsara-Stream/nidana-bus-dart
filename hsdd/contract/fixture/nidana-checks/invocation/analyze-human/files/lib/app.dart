import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

final class DeviceToken {
  const DeviceToken();
}

final Bus appBus = Bus();

void register(Bus bus) {
  bus.publish<Object?, DeviceToken>(EventTopic<DeviceToken>(name: 'device.token'), const DeviceToken());
}
