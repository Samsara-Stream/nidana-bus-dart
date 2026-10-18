codegen-plan-facts: runtime facts behind nidana.tooling.codegen's phase plan
(hsdd/spec/nidana.tooling.codegen.md, D3 and D4), step S39.

Part A, probe.mjs -> probe-output.txt (node probe.mjs > probe-output.txt 2>&1):
ADR-002 item 4's resolution probe for pub_semver, which nidana_dart_codegen
must declare because dart_style 3.1.14's DartFormatter requires a pub_semver
Version as languageVersion. A1: one resolution of every item 3 row (stand-in
members), item 7's pins, rxdart, plus pub_semver and json_schema (dev) in the
codegen stand-in: pub_semver 2.2.1, every direct package at item 4's table,
88 packages (the same count as ../constraint-lower-bounds/ P0, so pub_semver
was already in the resolution). A2: pub_semver ^2.2.1 resolves from no
lockfile with the codegen stand-in landing first, beside the plugin, and in
the full set. A3: DartFormatter(languageVersion: Version(3, 13, 0)) compiles,
formats and analyzes clean.

Part B, run.sh -> output.txt (./run.sh > output.txt 2>&1): how catalog's two
runners and the analyzer treat fixture packages. src/ is a pub workspace
(stand-ins: cpf_contracts for nidana_dart_contracts, cpf_flutter for the
Flutter member, which declares flutter_test as nidana_dart_runtime_flutter
does, cpf_host for nidana_dart_codegen) whose cpf_host/test/fixture/ holds two
fixture packages that are not members and are never resolved by pub, as
nidana-checks@v1's scan cases' files/app packages are. src/entry/ is the entry
point catalog generates (stand-in: it writes topology ids). tool/ holds two
helpers. run.sh copies src/ to work/ and removes it at the end.

- B1, B2, B3: dart run of the entry from the in-tree pure fixture package's
  root resolves through the workspace's package configuration, with or
  without --packages, with fvm or with the SDK's dart by path; nothing is
  left in the fixture package but the entry.
- B4: flutter test --no-pub from the in-tree Flutter fixture package crashes
  the tool (StateError in testCompilerBuildNativeAssets): the package is not
  in the workspace's resolution. In a first run of run.sh, before cpf_flutter
  declared flutter_test, the tool refused earlier: "cannot run without a dependency on
  either package:flutter_test or package:test".
- B5: the Flutter fixture under dart run fails on dart:ui, exit 254.
- B6: a registration importing its own package by package: URI does not
  resolve in an unresolved fixture package, exit 254.
- B7: the workspace root's fvm dart analyze --fatal-infos analyzes the
  in-tree fixture packages (their package: imports resolve) and reports
  avoid_relative_lib_imports for a tool/ library importing ../lib/; the
  error on entry/ is this experiment's own template, outside any package.
- B8: a temporary copy with a synthesized package configuration (the
  workspace's packages, absolute, plus itself) runs under dart run, exit 0,
  but dart run first tries and fails an implicit resolution.
- B9: the same copy under flutter test --no-pub crashes as B4 did.
- B11: a temporary copy resolved alone (flutter pub get --offline, the
  stand-in contracts overridden by path as ADR-002 Q18 describes) is refused
  by flutter test: no flutter_test or test in its resolution.
- B13: with flutter_test as a dev dependency, the same copy runs: exit 79,
  "No tests ran", the entry's output written.
- B12: a pure temporary copy resolved alone (dart pub get --offline) runs
  under dart run, exit 0, cleanly.
- B10: the analyzer resolves both in-tree fixtures and both synthesized-config
  copies to the stand-in packages and to Flutter, with no diagnostic.
