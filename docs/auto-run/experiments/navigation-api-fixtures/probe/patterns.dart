// P3: what the analyzer reports for a DeepLink where a resolved intent is
// expected, and for a NavRoute<void> type argument.
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

String kind(ResolvedNavIntent i) => switch (i) {
      DeepLink() => 'deep', // X1
      GoTo() => 'go',
      Replace() => 'replace',
      Back() => 'back',
      BackTo() => 'back-to',
      ShowModal() => 'modal',
      DismissModal() => 'dismiss',
    };

ResolvedNavIntent resolved(Uri u) => DeepLink(u); // X2

void main() {
  print(const NavRoute<void>('probe/x').argsType); // X3
  print(const NavRoute<void>('probe/x') == const NavRoute<Null>('probe/x')); // X4
}
