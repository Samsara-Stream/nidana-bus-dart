// The registration library of package app. It lists the app's own page
// topology; the domain package registers its own in its own tool/ library.
import 'package:app/payment_page.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

Iterable<Topology> catalogTopologies() => <Topology>[paymentPageTopology];
