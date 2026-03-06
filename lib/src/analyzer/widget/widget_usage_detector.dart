// lib/src/analyzer/widget/widget_usage_detector.dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

/// Widget 使用箇所の情報
class WidgetUsage {
  const WidgetUsage({
    required this.widgetName,
    required this.filePath,
  });

  /// 使用されている Widget 名
  final String widgetName;

  /// 使用しているファイルパス
  final String filePath;
}

/// AST を訪問し、既知の Widget の使用箇所を検出する。
///
/// MVP では名前ベースの判定を使用:
/// - InstanceCreationExpression（const/new 付き）
/// - MethodInvocation（暗黙的 new: `MyWidget()` や `MyWidget.named()`）
/// のコンストラクタ名が既知 Widget 名リストに含まれるかで判定する。
///
/// 注: parseString（構文解析のみ）では暗黙的 new は MethodInvocation になるため、
/// 両方のノード型を訪問する必要がある。
class WidgetUsageDetector {
  WidgetUsageDetector({required this.knownWidgets});

  /// 既知の Widget 名のセット（WidgetExtractor で収集したもの）
  final Set<String> knownWidgets;

  /// ファイル内で使用されている Widget を検出する。
  List<WidgetUsage> detectUsages(String filePath, String content) {
    final parseResult = parseString(content: content);
    final unit = parseResult.unit;

    final visitor = _UsageVisitor(filePath, knownWidgets);
    unit.visitChildren(visitor);
    return visitor.usages;
  }
}

/// AST Visitor: Widget 使用を検出する。
///
/// 構文解析のみ（型解決なし）では:
/// - `const MyWidget()` / `new MyWidget()` → InstanceCreationExpression
/// - `MyWidget()` → MethodInvocation（methodName = 'MyWidget', target = null）
/// - `MyWidget.named()` → MethodInvocation（methodName = 'named', target = SimpleIdentifier('MyWidget')）
class _UsageVisitor extends RecursiveAstVisitor<void> {
  _UsageVisitor(this.filePath, this.knownWidgets);

  final String filePath;
  final Set<String> knownWidgets;
  final List<WidgetUsage> usages = [];

  void _addIfKnown(String name) {
    if (knownWidgets.contains(name)) {
      usages.add(WidgetUsage(widgetName: name, filePath: filePath));
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    _addIfKnown(typeName);

    // 子ノードも訪問（ネストされた生成式を検出するため）
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target == null) {
      // MyWidget() — 暗黙的 new（関数呼び出しと同じ構文）
      _addIfKnown(node.methodName.name);
    } else if (target is SimpleIdentifier) {
      // MyWidget.named() — named コンストラクタ
      _addIfKnown(target.name);
    }

    // 子ノードも訪問
    super.visitMethodInvocation(node);
  }
}
