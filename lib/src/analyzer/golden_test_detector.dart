import 'dart:io';

import 'package:path/path.dart' as p;

/// Detects Golden Test files by scanning for `matchesGoldenFile` usage.
class GoldenTestDetector {
  GoldenTestDetector(this.projectRoot);

  final String projectRoot;

  static final _goldenPattern = RegExp(r'matchesGoldenFile\s*\(');

  /// Check if file content contains golden test assertions.
  bool isGoldenTest(String content) {
    return _goldenPattern.hasMatch(content);
  }

  /// Find all golden test files under test/ directory.
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

  /// From a set of impacted files, filter only those that are golden tests.
  Set<String> filterGoldenTests(Set<String> impactedFiles) {
    final goldenTests = <String>{};

    for (final filePath in impactedFiles) {
      if (!filePath.endsWith('.dart')) continue;

      // Only consider test files
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
