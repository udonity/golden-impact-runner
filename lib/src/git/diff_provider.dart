import 'dart:io';

import 'package:path/path.dart' as p;

/// git diff から変更された .dart ファイルの一覧を提供する。
class DiffProvider {
  DiffProvider(this.projectRoot);

  final String projectRoot;

  /// [baseBranch] と [head] の間で変更された .dart ファイルを取得する。
  ///
  /// デフォルトでは `origin/main` との比較。
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

  /// 明示的なファイルリストから変更された .dart ファイルを取得する（--changed フラグ用）。
  Set<String> resolveExplicitFiles(List<String> files) {
    return files
        .map((f) => p.isAbsolute(f) ? f : p.normalize(p.join(projectRoot, f)))
        .where((f) => f.endsWith('.dart'))
        .toSet();
  }
}

/// 生成ファイル（.g.dart, .freezed.dart, .gr.dart）を元ファイルに正規化する。
///
/// 元ファイルが存在すればそちらを返し、存在しなければ生成ファイル自体を返す。
class GeneratedFileNormalizer {
  /// 正規化対象のサフィックス一覧。
  static const _generatedSuffixes = ['.g.dart', '.freezed.dart', '.gr.dart'];

  /// 変更ファイル群を正規化して返す。
  static Set<String> normalize(Set<String> files) {
    return files.map(_normalizeOne).toSet();
  }

  static String _normalizeOne(String filePath) {
    for (final suffix in _generatedSuffixes) {
      if (filePath.endsWith(suffix)) {
        final basePath =
            '${filePath.substring(0, filePath.length - suffix.length)}.dart';
        if (File(basePath).existsSync()) {
          return basePath;
        }
        // 元ファイルが存在しない場合は生成ファイル自体を返す
        return filePath;
      }
    }
    return filePath;
  }
}

class DiffException implements Exception {
  DiffException(this.message);
  final String message;

  @override
  String toString() => 'DiffException: $message';
}
