import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'import_parser.dart';

/// Dart ファイルの有向依存グラフ。
///
/// 順方向（dependsOn）と逆方向（dependedOnBy）のマップを構築し、
/// 変更ファイル集合から BFS で影響を受ける全ファイルを探索する。
class DependencyGraph {
  DependencyGraph._({
    required this.dependsOn,
    required this.dependedOnBy,
    required this.allFiles,
  });

  /// ファイル → そのファイルが依存するファイル集合（import 先）
  final Map<String, Set<String>> dependsOn;

  /// ファイル → そのファイルに依存するファイル集合（逆辺）
  final Map<String, Set<String>> dependedOnBy;

  /// プロジェクト内の既知の .dart ファイルすべて
  final Set<String> allFiles;

  /// [projectRoot] 配下のすべての .dart ファイルを走査して依存グラフを構築する。
  ///
  /// `lib/` と `test/` の両ディレクトリを走査する。
  factory DependencyGraph.build({
    required String projectRoot,
    required String packageName,
  }) {
    final parser = ImportParser(projectRoot, packageName);
    final dependsOn = <String, Set<String>>{};
    final dependedOnBy = <String, Set<String>>{};
    final allFiles = <String>{};

    final dirsToScan = ['lib', 'test']
        .map((d) => Directory(p.join(projectRoot, d)))
        .where((d) => d.existsSync());

    for (final dir in dirsToScan) {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final filePath = p.normalize(file.path);
        allFiles.add(filePath);

        final deps = parser.parseDependencies(filePath);
        dependsOn[filePath] = deps;

        for (final dep in deps) {
          dependedOnBy.putIfAbsent(dep, () => {}).add(filePath);
        }
      }
    }

    return DependencyGraph._(
      dependsOn: dependsOn,
      dependedOnBy: dependedOnBy,
      allFiles: allFiles,
    );
  }

  /// [changedFiles] の変更によって影響を受ける全ファイルを検索する。
  ///
  /// 逆依存グラフ（dependedOnBy）を BFS で走査し、
  /// 推移的に影響を受けるファイルをすべて返す。
  Set<String> findImpactedFiles(Set<String> changedFiles) {
    final visited = <String>{};
    final queue = Queue<String>();

    for (final file in changedFiles) {
      if (!visited.contains(file)) {
        visited.add(file);
        queue.add(file);
      }
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final dependents = dependedOnBy[current];
      if (dependents == null) continue;

      for (final dep in dependents) {
        if (!visited.contains(dep)) {
          visited.add(dep);
          queue.add(dep);
        }
      }
    }

    return visited;
  }
}
