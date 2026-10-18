import 'package:cpf_contracts/cpf_contracts.dart';
import 'package:flutter/widgets.dart';

class PageTopology extends Topology {
  const PageTopology();

  @override
  String get topologyId => 'page';
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
