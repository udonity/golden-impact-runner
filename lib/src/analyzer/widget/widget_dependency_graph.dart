// lib/src/analyzer/widget/widget_dependency_graph.dart
import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../dependency_graph.dart';
import 'widget_extractor.dart';
import 'widget_usage_detector.dart';

/// Widget 単位の依存グラフ。
///
/// ファイルレベルの import 依存グラフ（Phase 1）をベースに、
/// Widget の定義・使用関係を重ねて精密な影響範囲を算出する。
///
/// 入出力はファイルパス単位。中間の解析精度だけが Widget 単位に向上する。
///
/// 制約: 同名の Widget が異なるファイルに定義されている場合、
/// 後に走査されたファイルの定義で上書きされる（MVP の既知の制限事項）。
class WidgetDependencyGraph {
  WidgetDependencyGraph._({
    required this.fileGraph,
    required this.widgetToFiles,
    required this.fileToWidgets,
  });

  /// ファイルレベルの依存グラフ（Phase 1 の DependencyGraph を再利用）
  final DependencyGraph fileGraph;

  /// Widget名 → そのWidgetを使用しているファイルのセット
  final Map<String, Set<String>> widgetToFiles;

  /// ファイルパス → そのファイルで定義されている Widget 名のセット
  final Map<String, Set<String>> fileToWidgets;

  /// プロジェクト内の全 .dart ファイル（fileGraph から委譲）
  Set<String> get allFiles => fileGraph.allFiles;

  /// プロジェクトを解析して Widget 依存グラフを構築する。
  factory WidgetDependencyGraph.build({
    required String projectRoot,
    required String packageName,
  }) {
    // 1. ファイルレベルの依存グラフを構築（DependencyGraph に委譲）
    final fileGraph = DependencyGraph.build(
      projectRoot: projectRoot,
      packageName: packageName,
    );

    // 2. 全ファイルを1回だけパースして AST をキャッシュ
    final parsedUnits = <String, CompilationUnit>{};
    for (final filePath in fileGraph.allFiles) {
      final file = File(filePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        parsedUnits[filePath] = parseString(content: content).unit;
      }
    }

    // 3. Widget 定義を収集（キャッシュ済み AST を使用）
    final extractor = WidgetExtractor();
    final fileToWidgets = <String, Set<String>>{};
    final widgetDefinitions = <String, WidgetDefinition>{};

    for (final entry in parsedUnits.entries) {
      final widgets =
          extractor.extractWidgetsFromUnit(entry.key, entry.value);
      if (widgets.isNotEmpty) {
        fileToWidgets[entry.key] = widgets.map((w) => w.name).toSet();
        for (final w in widgets) {
          widgetDefinitions[w.name] = w;
        }
      }
    }

    // 4. Widget 使用を検出（同じキャッシュ済み AST を再利用）
    final knownWidgets = widgetDefinitions.keys.toSet();
    final usageDetector = WidgetUsageDetector(knownWidgets: knownWidgets);
    final widgetToFiles = <String, Set<String>>{};

    for (final entry in parsedUnits.entries) {
      final usages =
          usageDetector.detectUsagesFromUnit(entry.key, entry.value);
      for (final usage in usages) {
        widgetToFiles
            .putIfAbsent(usage.widgetName, () => {})
            .add(entry.key);
      }
    }

    return WidgetDependencyGraph._(
      fileGraph: fileGraph,
      widgetToFiles: widgetToFiles,
      fileToWidgets: fileToWidgets,
    );
  }

  /// 変更ファイル → 影響を受けるファイルを返す。
  ///
  /// Widget 単位の解析により、ファイルレベルより精密な影響範囲を算出:
  /// 1. 変更ファイル内の Widget 定義を特定
  /// 2. Widget 定義を持つファイル → Widget 使用エッジのみで伝搬（過検出を削減）
  /// 3. Widget 定義を持たないファイル → ファイルレベルの import チェーンにフォールバック
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

      final widgets = fileToWidgets[current];
      final hasWidgetDefinitions = widgets != null && widgets.isNotEmpty;

      if (hasWidgetDefinitions) {
        // Widget 定義を持つファイル → Widget 使用エッジのみで伝搬
        // ファイルレベルの import チェーンを辿らないことで過検出を削減する
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
      } else {
        // Widget 定義を持たないファイル → ファイルレベルの逆依存にフォールバック
        final fileDependents = fileGraph.dependedOnBy[current];
        if (fileDependents != null) {
          for (final dep in fileDependents) {
            if (!visited.contains(dep)) {
              visited.add(dep);
              queue.add(dep);
            }
          }
        }
      }
    }

    return visited;
  }
}
