import 'dart:io';

import 'package:path/path.dart' as p;

/// Dart の import/export/part ディレクティブをパースし、
/// 絶対ファイルパスに解決する。
class ImportParser {
  ImportParser(this.projectRoot, this.packageName);

  final String projectRoot;
  final String packageName;

  // import 'x'; export 'x'; にマッチ
  static final _importExportPattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  // part 'x'; にマッチするが part of 'x'; にはマッチしない。
  // `part of` を除外するために否定先読みを使用。
  static final _partPattern = RegExp(
    r'''^\s*part\s+(?!of\b)['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Dart ソースから import/export/part の URI をすべて抽出する。
  List<String> extractDependencyUris(String content) {
    final uris = <String>[];

    for (final match in _importExportPattern.allMatches(content)) {
      uris.add(match.group(1)!);
    }

    for (final match in _partPattern.allMatches(content)) {
      uris.add(match.group(1)!);
    }

    return uris;
  }

  /// import URI を絶対ファイルパスに解決する。
  /// 無視すべき URI（dart: SDK や外部パッケージ）の場合は null を返す。
  String? resolveUri(String uri, String currentFilePath) {
    // SDK import は無視
    if (uri.startsWith('dart:')) return null;

    // 自プロジェクトの package import
    if (uri.startsWith('package:$packageName/')) {
      final relativePath = uri.substring('package:$packageName/'.length);
      return p.normalize(p.join(projectRoot, 'lib', relativePath));
    }

    // 外部パッケージの import は無視
    if (uri.startsWith('package:')) return null;

    // 相対 import
    final dir = p.dirname(currentFilePath);
    return p.normalize(p.join(dir, uri));
  }

  /// 単一ファイルをパースし、解決済みの依存パスをすべて返す。
  Set<String> parseDependencies(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return {};

    final content = file.readAsStringSync();
    final uris = extractDependencyUris(content);
    final resolved = <String>{};

    for (final uri in uris) {
      final path = resolveUri(uri, filePath);
      if (path != null) {
        resolved.add(path);
      }
    }

    return resolved;
  }
}
