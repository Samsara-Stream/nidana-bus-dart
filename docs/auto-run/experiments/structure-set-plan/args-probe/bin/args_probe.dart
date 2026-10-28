import 'package:args/args.dart';

void main() {
  final ArgParser parser = ArgParser()
    ..addFlag('all', negatable: false)
    ..addMultiOption('set')
    ..addMultiOption('guarantee');
  for (final List<String> a in <List<String>>[
    <String>['topic-model', '--set', ''],
    <String>['topic-model', '--set='],
    <String>['topic-model', '--set', 'structure,schema', '--set=surface'],
    <String>['topic-model', '--guarantee', 'G1, G2'],
    <String>['topic-model', '--guarantee', 'G1,'],
    <String>['topic-model', '--set'],
    <String>['--frobnicate', 'topic-model'],
  ]) {
    try {
      final ArgResults r = parser.parse(a);
      print('$a -> set=${r.multiOption('set').map((String s) => "'$s'").toList()} '
          'guarantee=${r.multiOption('guarantee').map((String s) => "'$s'").toList()} rest=${r.rest}');
    } on FormatException catch (e) {
      print('$a -> FormatException: ${e.message}');
    }
  }
}
