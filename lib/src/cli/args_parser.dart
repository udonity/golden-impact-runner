import 'runner.dart';

/// CLI 引数を [RunnerConfig] にパースする。
///
/// `package:args` に依存しない — ランタイムバイナリの外部依存をゼロに保つ。
class ArgsParser {
  static const _help = '''
golden_impact_runner — Find Flutter Golden Tests affected by code changes.

Usage: golden_impact_runner [options]

Options:
  --base <branch>     Base branch for git diff (default: origin/main)
  --head <ref>        Head ref for git diff (default: HEAD)
  --changed <file>    Specify changed file(s) explicitly (repeatable)
  --project <dir>     Project root directory (default: current directory)
  --format <fmt>      Output format: text, json, command (default: text)
  --exclude <pattern> Exclude files matching glob pattern (repeatable)
  --analysis-mode <mode>  Analysis mode: file, widget (default: file)
  --verbose, -v       Print diagnostic info to stderr
  --help, -h          Show this help message
''';

  /// [args] をパースして [RunnerConfig] を返す。--help が指定された場合は null。
  static RunnerConfig? parse(List<String> args) {
    String? projectRoot;
    var baseBranch = 'origin/main';
    var head = 'HEAD';
    final changedFiles = <String>[];
    final excludePatterns = <String>[];
    var format = OutputFormat.text;
    var analysisMode = AnalysisMode.file;
    var verbose = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--help' || '-h':
          // ignore: avoid_print
          print(_help);
          return null;
        case '--verbose' || '-v':
          verbose = true;
        case '--base':
          baseBranch = _nextArg(args, i, '--base');
          i++;
        case '--head':
          head = _nextArg(args, i, '--head');
          i++;
        case '--changed':
          changedFiles.add(_nextArg(args, i, '--changed'));
          i++;
        case '--exclude':
          excludePatterns.add(_nextArg(args, i, '--exclude'));
          i++;
        case '--project':
          projectRoot = _nextArg(args, i, '--project');
          i++;
        case '--format':
          final fmt = _nextArg(args, i, '--format');
          format = switch (fmt) {
            'json' => OutputFormat.json,
            'text' => OutputFormat.text,
            'command' => OutputFormat.command,
            _ => throw FormatException('Unknown format: $fmt'),
          };
          i++;
        case '--analysis-mode':
          final mode = _nextArg(args, i, '--analysis-mode');
          analysisMode = switch (mode) {
            'file' => AnalysisMode.file,
            'widget' => AnalysisMode.widget,
            _ => throw FormatException('Unknown analysis mode: $mode'),
          };
          i++;
        default:
          throw FormatException('Unknown argument: $arg');
      }
    }

    return RunnerConfig(
      projectRoot: projectRoot ?? '.',
      baseBranch: baseBranch,
      head: head,
      changedFiles: changedFiles,
      excludePatterns: excludePatterns,
      format: format,
      analysisMode: analysisMode,
      verbose: verbose,
    );
  }

  static String _nextArg(List<String> args, int i, String flag) {
    if (i + 1 >= args.length) {
      throw FormatException('$flag requires a value');
    }
    return args[i + 1];
  }
}
