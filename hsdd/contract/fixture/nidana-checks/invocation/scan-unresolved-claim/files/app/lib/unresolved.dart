// Code that does not resolve (nidana-checks@v1 The workspace scan). The
// prefixed import names a package the configuration lacks, and `Buss` is
// misspelt, so neither `missing.StateTopic`, `missing.Bus` nor `Buss` is
// declared in any library, and none is nidana's. The creation is not a topic
// creation, so its name collides with nothing; the invocations are not claim
// sites, so their write sets are not reported. The scan reports nothing here;
// `dart analyze` reports the compile errors.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtme/nidana_dart_runtme.dart' as missing;

import 'claims.dart';

final Object unresolvedTopic = missing.StateTopic<int>(name: 'cart.items', initial: 0);

void fromMissingPackage(missing.Bus bus) {
  bus.publisher(const ServiceSource('u'), writes: owned);
}

void misspelt(Buss bus) {
  bus.publisher(const ServiceSource('v'), writes: owned);
}
