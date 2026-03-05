import 'dart:io';

import 'package:path/path.dart' as p;

/// Provides the list of changed .dart files from git diff.
class DiffProvider {
  DiffProvider(this.projectRoot);

  final String projectRoot;

  /// Get changed .dart files between [baseBranch] and [head].
  ///
  /// Defaults to comparing against `origin/main`.
  Future<Set<String>> getChangedDartFiles({
    String baseBranch = 'origin/main',
    String head = 'HEAD',
  }) async {
    final result = await Process.run(
      'git',
      ['diff', '--name-only', '--diff-filter=ACMR', '$baseBranch...$head'],
      workingDirectory: projectRoot,
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw DiffException('git diff failed (exit ${result.exitCode}): $stderr');
    }

    final output = (result.stdout as String).trim();
    if (output.isEmpty) return {};

    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.endsWith('.dart'))
        .map((line) => p.normalize(p.join(projectRoot, line)))
        .toSet();
  }

  /// Get changed .dart files from explicit file list (for --changed flag).
  Set<String> resolveExplicitFiles(List<String> files) {
    return files
        .map((f) => p.isAbsolute(f) ? f : p.normalize(p.join(projectRoot, f)))
        .where((f) => f.endsWith('.dart'))
        .toSet();
  }
}

class DiffException implements Exception {
  DiffException(this.message);
  final String message;

  @override
  String toString() => 'DiffException: $message';
}
