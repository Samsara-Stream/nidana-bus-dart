// The registration library of package domain: every topology the package
// declares, constructed with the arguments the app's bootstrap passes.
import 'package:domain/domain.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

Iterable<Topology> catalogTopologies() => <Topology>[
      const CartTopology(),
      pricingTopology(flatRate),
    ];
