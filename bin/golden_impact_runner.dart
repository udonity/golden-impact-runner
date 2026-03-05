import 'dart:io';

import 'package:golden_impact_runner/src/cli/args_parser.dart';
import 'package:golden_impact_runner/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  try {
    final config = ArgsParser.parse(args);
    if (config == null) return; // --help was printed

    final runner = Runner();
    final exitCode = await runner.run(config);
    exit(exitCode);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('Run with --help for usage information.');
    exit(2);
  }
}
