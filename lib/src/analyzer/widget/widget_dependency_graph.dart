// lib/src/analyzer/widget/widget_dependency_graph.dart
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../import_parser.dart';
import 'widget_extractor.dart';
import 'widget_usage_detector.dart';

/// Widget 単位の依存グラフ。
///
/// ファイルレベルの import 依存グラフ（Phase 1）をベースに、
/// Widget の定義・使用関係を重ねて精密な影響範囲を算出する。
///
/// 入出力はファイルパス単位。中間の解析精度だけが Widget 単位に向上する。
class WidgetDependencyGraph {
  WidgetDependencyGraph._({
    required this.fileDependedOnBy,
    required this.widgetToFiles,
    required this.fileToWidgets,
    required this.allFiles,
  });

  /// ファイルレベルの逆依存マップ（Phase 1 と同じ）
  final Map<String, Set<String>> fileDependedOnBy;

  /// Widget名 → そのWidgetを使用しているファイルのセット
  final Map<String, Set<String>> widgetToFiles;

  /// ファイルパス → そのファイルで定義されている Widget 名のセット
  final Map<String, Set<String>> fileToWidgets;

  /// プロジェクト内の全 .dart ファイル
  final Set<String> allFiles;

  /// プロジェクトを解析して Widget 依存グラフを構築する。
  factory WidgetDependencyGraph.build({
    required String projectRoot,
    required String packageName,
  }) {
    final parser = ImportParser(projectRoot, packageName);
    final extractor = WidgetExtractor();

    // 1. ファイルレベルの依存グラフを構築（Phase 1 と同じロジック）
    final fileDependedOnBy = <String, Set<String>>{};
    final allFiles = <String>{};

    final dirsToScan = ['lib', 'test']
        .map((d) => Directory(p.join(projectRoot, d)))
        .where((d) => d.existsSync());

    final fileContents = <String, String>{};

    for (final dir in dirsToScan) {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final filePath = p.normalize(file.path);
        allFiles.add(filePath);
        fileContents[filePath] = file.readAsStringSync();

        final deps = parser.parseDependencies(filePath);

        for (final dep in deps) {
          fileDependedOnBy.putIfAbsent(dep, () => {}).add(filePath);
        }
      }
    }

    // 2. Widget 定義を収集
    final fileToWidgets = <String, Set<String>>{};
    final widgetDefinitions = <String, WidgetDefinition>{};

    for (final entry in fileContents.entries) {
      final widgets = extractor.extractWidgets(entry.key, entry.value);
      if (widgets.isNotEmpty) {
        fileToWidgets[entry.key] = widgets.map((w) => w.name).toSet();
        for (final w in widgets) {
          widgetDefinitions[w.name] = w;
        }
      }
    }

    // 3. Widget 使用を検出
    final knownWidgets = widgetDefinitions.keys.toSet();
    final usageDetector = WidgetUsageDetector(knownWidgets: knownWidgets);
    final widgetToFiles = <String, Set<String>>{};

    for (final entry in fileContents.entries) {
      final usages = usageDetector.detectUsages(entry.key, entry.value);
      for (final usage in usages) {
        widgetToFiles
            .putIfAbsent(usage.widgetName, () => {})
            .add(entry.key);
      }
    }

    return WidgetDependencyGraph._(
      fileDependedOnBy: fileDependedOnBy,
      widgetToFiles: widgetToFiles,
      fileToWidgets: fileToWidgets,
      allFiles: allFiles,
    );
  }

  /// 変更ファイル → 影響を受けるファイルを返す。
  ///
  /// Widget 単位の解析により、ファイルレベルより精密な影響範囲を算出:
  /// 1. 変更ファイル内の Widget 定義を特定
  /// 2. それらの Widget を使用しているファイルを逆引き
  /// 3. Widget を含まないファイルの変更はファイルレベルの import チェーンにフォールバック
  /// 4. BFS で推移的に影響を伝搬
  Set<String> findImpactedFiles(Set<String> changedFiles) {
    final visited = <String>{};
    final queue = Queue<String>();

    // 初期シードをキューに追加
    for (final file in changedFiles) {
      if (!visited.contains(file)) {
        visited.add(file);
        queue.add(file);
      }
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      // ファイルに Widget 定義がある場合、Widget 使用経由の依存を追跡
      final widgets = fileToWidgets[current];
      if (widgets != null && widgets.isNotEmpty) {
        for (final widgetName in widgets) {
          final usedByFiles = widgetToFiles[widgetName];
          if (usedByFiles != null) {
            for (final file in usedByFiles) {
              if (!visited.contains(file)) {
                visited.add(file);
                queue.add(file);
              }
            }
          }
        }
      }

      // ファイルレベルの逆依存も常に追跡（フォールバック + 非Widget依存の伝搬）
      final fileDependents = fileDependedOnBy[current];
      if (fileDependents != null) {
        for (final dep in fileDependents) {
          if (!visited.contains(dep)) {
            visited.add(dep);
            queue.add(dep);
          }
        }
      }
    }

    return visited;
  }
}
