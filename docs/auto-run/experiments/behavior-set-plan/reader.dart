// Reads each conformance library given by path with the replay tool's own
// fixture reader, as the behavior set would, and prints how many case names
// it reads and how many begin with G{n} and a space. Run from the repository
// root through `fvm dart run`, which resolves package:nidana_contract_check
// from the workspace's package configuration.
import 'dart:io';

import 'package:nidana_contract_check/src/dart_library.dart';

final RegExp _id = RegExp(r'^G([1-9][0-9]*) ');

void main(List<String> paths) {
  for (final String path in paths) {
    final DartLibrary library = readDartLibrary(File(path).readAsStringSync());
    final List<String?> names = <String?>[
      for (final CaseList list in library.caseLists)
        for (final CaseName name in list.cases) name.name,
    ];
    final int withId = names
        .where((String? name) => name != null && _id.hasMatch(name))
        .length;
    final Set<String> ids = <String>{
      for (final String? name in names)
        if (name?.split(' ').first case final String head
            when name != null && _id.hasMatch(name))
          head,
    };
    print(
      '$path: ${library.caseLists.length} case list(s), ${names.length} '
      'case names, $withId begin with G{n} and a space, ${ids.length} '
      'distinct ids',
    );
  }
}
