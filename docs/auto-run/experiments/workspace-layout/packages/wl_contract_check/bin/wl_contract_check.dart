import 'package:args/args.dart';

void main(List<String> args) {
  final parsed = (ArgParser()..addOption('set')).parse(args);
  print('wl_contract_check ran: rest=${parsed.rest} set=${parsed.option('set')}');
}
