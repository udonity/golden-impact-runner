import 'dart:io';

import 'package:path/path.dart' as p;

/// Golden Test ファイルを検出する。
///
/// 以下のパターンをサポート:
/// - `matchesGoldenFile(` — Flutter 標準の golden test
/// - `goldenTest(` — Alchemist パッケージ
/// - `GoldenTestGroup(` / `GoldenTestScenario(` — Alchemist のヘルパー
class GoldenTestDetector {
  GoldenTestDetector(this.projectRoot);

  final String projectRoot;

  static final _goldenPatterns = [
    RegExp(r'matchesGoldenFile\s*\('),
    RegExp(r'goldenTest\s*\('),
    RegExp(r'GoldenTestGroup\s*\('),
    RegExp(r'GoldenTestScenario\s*\('),
  ];

  /// ファイル内容に golden test アサーションが含まれるか判定する。
  bool isGoldenTest(String content) {
    return _goldenPatterns.any((p) => p.hasMatch(content));
  }

  /// test/ ディレクトリ配下のすべての golden test ファイルを検索する。
  Set<String> findAllGoldenTests() {
    final testDir = Directory(p.join(projectRoot, 'test'));
    if (!testDir.existsSync()) return {};

    final goldenTests = <String>{};

    for (final file in testDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;

      final content = file.readAsStringSync();
      if (isGoldenTest(content)) {
        goldenTests.add(p.normalize(file.path));
      }
    }

    return goldenTests;
  }

  /// 影響を受けるファイル集合から golden test のみを抽出する。
  Set<String> filterGoldenTests(Set<String> impactedFiles) {
    final goldenTests = <String>{};

    for (final filePath in impactedFiles) {
      if (!filePath.endsWith('.dart')) continue;

      // テストファイルのみ対象
      final relative = p.relative(filePath, from: projectRoot);
      if (!relative.startsWith('test${p.separator}')) continue;

      final file = File(filePath);
      if (!file.existsSync()) continue;

      final content = file.readAsStringSync();
      if (isGoldenTest(content)) {
        goldenTests.add(filePath);
      }
    }

    return goldenTests;
  }
}
