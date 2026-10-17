import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class CartItems {
  const CartItems();
}

enum Mode { a, b }

typedef Alias = CartItems;

abstract final class T {
  static const StateTopic<CartItems> interface = StateTopic<CartItems>(name: 'p.interface', initial: CartItems());
  static const StateTopic<List<CartItems>> generic = StateTopic<List<CartItems>>(name: 'p.generic', initial: <CartItems>[]);
  static const StateTopic<CartItems?> nullable = StateTopic<CartItems?>(name: 'p.nullable', initial: null);
  static const StateTopic<Mode> enumeration = StateTopic<Mode>(name: 'p.enum', initial: Mode.a);
  static const StateTopic<(int, String)> record = StateTopic<(int, String)>(name: 'p.record', initial: (0, ''));
  static const StateTopic<({int a})> namedRecord = StateTopic<({int a})>(name: 'p.named-record', initial: (a: 0));
  static const StateTopic<Alias> alias = StateTopic<Alias>(name: 'p.alias', initial: CartItems());
  static const StateTopic<Map<String, int?>> map = StateTopic<Map<String, int?>>(name: 'p.map', initial: <String, int?>{});
  static final StateTopic<int Function(String)> function = StateTopic<int Function(String)>(name: 'p.function', initial: _len);
}

int _len(String s) => s.length;

final List<Topic<Object?>> all = <Topic<Object?>>[
  T.interface, T.generic, T.nullable, T.enumeration, T.record, T.namedRecord, T.alias, T.map, T.function,
];
