// An example with no pubspec of its own: part of the member's package.
import 'package:wl_contracts/wl_contracts.dart';

void main() {
  print(isDomainEntity(const TopicName('auth.state')));
}
