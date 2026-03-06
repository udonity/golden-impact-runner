// lib/src/analyzer/widget/widget_extractor.dart
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;

/// Widget 定義の情報
class WidgetDefinition {
  const WidgetDefinition({
    required this.name,
    required this.filePath,
    required this.superclass,
  });

  /// Widget クラス名（例: "MyButton"）
  final String name;

  /// 定義されているファイルパス
  final String filePath;

  /// 継承元クラス名（"StatelessWidget" or "StatefulWidget"）
  final String superclass;
}

/// AST 解析で Dart ファイルから Widget 定義を抽出する。
///
/// MVP では名前ベースの簡易判定を使用:
/// extends 句が "StatelessWidget" または "StatefulWidget" であるクラスのみ検出。
/// 中間基底クラス経由（例: class Foo extends MyBaseWidget）は検出しない。
class WidgetExtractor {
  /// 既知の Widget 基底クラス名
  static const _widgetSuperclasses = {'StatelessWidget', 'StatefulWidget'};

  /// ファイルの AST を解析し、Widget 定義を返す。
  List<WidgetDefinition> extractWidgets(String filePath, String content) {
    final parseResult = parseString(content: content);
    final unit = parseResult.unit;

    final visitor = _WidgetVisitor(filePath);
    unit.visitChildren(visitor);
    return visitor.widgets;
  }

  /// プロジェクト全体をスキャンし、全 Widget 定義を収集する。
  /// 戻り値はファイルパス → Widget定義リストのマップ。
  Map<String, List<WidgetDefinition>> extractAllWidgets(String projectRoot) {
    final result = <String, List<WidgetDefinition>>{};
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) return result;

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final filePath = p.normalize(file.path);
      final content = file.readAsStringSync();
      final widgets = extractWidgets(filePath, content);
      if (widgets.isNotEmpty) {
        result[filePath] = widgets;
      }
    }

    return result;
  }
}

/// AST Visitor: ClassDeclaration を訪問して Widget 定義を収集する。
class _WidgetVisitor extends RecursiveAstVisitor<void> {
  _WidgetVisitor(this.filePath);

  final String filePath;
  final List<WidgetDefinition> widgets = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) return;

    final superclassName = extendsClause.superclass.name2.lexeme;
    if (WidgetExtractor._widgetSuperclasses.contains(superclassName)) {
      widgets.add(WidgetDefinition(
        name: node.name.lexeme,
        filePath: filePath,
        superclass: superclassName,
      ));
    }

    // 子ノードは訪問しない（ネストされたクラスは Dart にないが念のため）
  }
}
