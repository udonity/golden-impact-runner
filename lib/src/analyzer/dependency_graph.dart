import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'import_parser.dart';

/// A directed dependency graph of Dart files.
///
/// Builds forward (dependsOn) and reverse (dependedOnBy) maps,
/// then supports BFS traversal to find all impacted files from a
/// set of changed files.
class DependencyGraph {
  DependencyGraph._({
    required this.dependsOn,
    required this.dependedOnBy,
    required this.allFiles,
  });

  /// file -> set of files it depends on (imports)
  final Map<String, Set<String>> dependsOn;

  /// file -> set of files that depend on it (reverse edges)
  final Map<String, Set<String>> dependedOnBy;

  /// All known .dart files in the project
  final Set<String> allFiles;

  /// Build a dependency graph by scanning all .dart files under [projectRoot].
  ///
  /// Scans both `lib/` and `test/` directories.
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

  /// Find all files impacted by changes to [changedFiles].
  ///
  /// Traverses the reverse dependency graph (dependedOnBy) using BFS
  /// to find all transitively affected files.
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
