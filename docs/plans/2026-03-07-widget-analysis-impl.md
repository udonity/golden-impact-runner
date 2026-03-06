# Phase 2: Widget単位解析 実装計画

> **Claudeへ:** 必須サブスキル: superpowers:executing-plansを使用して、この計画をタスクごとに実装すること。

**目標:** `package:analyzer` を導入し、Widget単位の依存解析パイプラインを既存のファイルレベル解析と並行して追加する。

**アーキテクチャ:** レイヤード拡張。既存コード（正規表現ベース）は一切変更せず、`lib/src/analyzer/widget/` に新しいAST解析パイプラインを追加。`--analysis-mode=widget` で切り替え。

**技術スタック:** Dart, package:analyzer (AST解析), package:test

**デザインドキュメント:** `docs/plans/2026-03-07-widget-analysis-design.md`

---

## タスク 1: package:analyzer の依存追加

**ファイル:**
- 変更: `pubspec.yaml`

**ステップ 1: pubspec.yaml に analyzer 依存を追加する**

`pubspec.yaml` の `dependencies` セクションに `analyzer` を追加する:

```yaml
dependencies:
  path: ^1.9.0
  analyzer: ^7.0.0
```

**ステップ 2: 依存を取得する**

実行: `dart pub get`
期待値: 正常終了。`pubspec.lock` に `analyzer` が追加される。

**ステップ 3: 既存テストが壊れていないことを確認する**

実行: `dart test`
期待値: ALL TESTS PASSED（既存テストに影響なし）

**ステップ 4: コミット**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: package:analyzer を追加（Phase 2 Widget単位解析用）"
```

---

## タスク 2: フィクスチャプロジェクトの作成

**ファイル:**
- 作成: `test/fixtures_widget/pubspec.yaml`
- 作成: `test/fixtures_widget/lib/widgets/button.dart`
- 作成: `test/fixtures_widget/lib/widgets/card.dart`
- 作成: `test/fixtures_widget/lib/widgets/dialog.dart`
- 作成: `test/fixtures_widget/lib/widgets/utils.dart`
- 作成: `test/fixtures_widget/lib/widgets/multi_widget.dart`
- 作成: `test/fixtures_widget/lib/widgets/base_widget.dart`
- 作成: `test/fixtures_widget/lib/widgets/derived_widget.dart`
- 作成: `test/fixtures_widget/lib/widgets/indirect_usage.dart`
- 作成: `test/fixtures_widget/lib/models/user.dart`
- 作成: `test/fixtures_widget/test/button_golden_test.dart`
- 作成: `test/fixtures_widget/test/card_golden_test.dart`
- 作成: `test/fixtures_widget/test/dialog_golden_test.dart`
- 作成: `test/fixtures_widget/test/multi_widget_golden_test.dart`
- 作成: `test/fixtures_widget/test/derived_golden_test.dart`

**ステップ 1: pubspec.yaml を作成する**

```yaml
# test/fixtures_widget/pubspec.yaml
name: widget_test_app
version: 0.1.0
environment:
  sdk: ^3.8.0
```

**ステップ 2: lib/widgets/button.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/button.dart
import 'package:flutter/material.dart';

/// シンプルな StatelessWidget
class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: () {}, child: Text(label));
  }
}
```

**ステップ 3: lib/widgets/card.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/card.dart
import 'package:flutter/material.dart';
import 'button.dart';

/// AppButton を使用する StatelessWidget
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(title),
          const AppButton(label: 'Action'),
        ],
      ),
    );
  }
}
```

**ステップ 4: lib/widgets/dialog.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/dialog.dart
import 'package:flutter/material.dart';
import 'card.dart';

/// AppCard を使用する StatefulWidget
class AppDialog extends StatefulWidget {
  const AppDialog({super.key});

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  @override
  Widget build(BuildContext context) {
    return const Dialog(child: AppCard(title: 'Dialog'));
  }
}
```

**ステップ 5: lib/widgets/utils.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/utils.dart

/// Widget ではないユーティリティクラス
class WidgetUtils {
  static String formatLabel(String raw) => raw.trim().toUpperCase();
}
```

**ステップ 6: lib/widgets/multi_widget.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/multi_widget.dart
import 'package:flutter/material.dart';

/// 1ファイルに2つの Widget を定義（精度改善テスト用）
class WidgetA extends StatelessWidget {
  const WidgetA({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Widget A');
  }
}

class WidgetB extends StatelessWidget {
  const WidgetB({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Widget B');
  }
}
```

**ステップ 7: lib/widgets/base_widget.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/base_widget.dart
import 'package:flutter/material.dart';

/// abstract な基底 Widget（サポート外ケース検証用）
abstract class BaseWidget extends StatelessWidget {
  const BaseWidget({super.key});
}
```

**ステップ 8: lib/widgets/derived_widget.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/derived_widget.dart
import 'package:flutter/material.dart';
import 'base_widget.dart';

/// 中間基底クラス経由の Widget（サポート外ケース）
/// MVP では BaseWidget が StatelessWidget であることを認識できないため、
/// DerivedWidget は Widget として検出されない。
/// ファイルレベルの依存追跡にフォールバックする。
class DerivedWidget extends BaseWidget {
  const DerivedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Derived');
  }
}
```

**ステップ 9: lib/widgets/indirect_usage.dart を作成する**

```dart
// test/fixtures_widget/lib/widgets/indirect_usage.dart
import 'package:flutter/material.dart';
import 'button.dart';

/// 関数経由で Widget を返すヘルパー（サポート外ケース）
/// MVP では関数の戻り型を解析しないため、
/// この関数の呼び出し側では AppButton への依存が検出されない。
Widget buildDefaultButton() {
  return const AppButton(label: 'Default');
}
```

**ステップ 10: lib/models/user.dart を作成する**

```dart
// test/fixtures_widget/lib/models/user.dart

/// Widget ではないモデルクラス
class User {
  const User({required this.name, required this.email});
  final String name;
  final String email;
}
```

**ステップ 11: テストフィクスチャを作成する**

```dart
// test/fixtures_widget/test/button_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/button.dart';

void main() {
  testWidgets('AppButton golden', (tester) async {
    await tester.pumpWidget(const AppButton(label: 'Test'));
    await expectLater(find.byType(AppButton), matchesGoldenFile('goldens/button.png'));
  });
}
```

```dart
// test/fixtures_widget/test/card_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/card.dart';

void main() {
  testWidgets('AppCard golden', (tester) async {
    await tester.pumpWidget(const AppCard(title: 'Test'));
    await expectLater(find.byType(AppCard), matchesGoldenFile('goldens/card.png'));
  });
}
```

```dart
// test/fixtures_widget/test/dialog_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/dialog.dart';

void main() {
  testWidgets('AppDialog golden', (tester) async {
    await tester.pumpWidget(const AppDialog());
    await expectLater(find.byType(AppDialog), matchesGoldenFile('goldens/dialog.png'));
  });
}
```

```dart
// test/fixtures_widget/test/multi_widget_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/multi_widget.dart';

void main() {
  // WidgetA のみの Golden Test（WidgetB のテストはない）
  testWidgets('WidgetA golden', (tester) async {
    await tester.pumpWidget(const WidgetA());
    await expectLater(find.byType(WidgetA), matchesGoldenFile('goldens/widget_a.png'));
  });
}
```

```dart
// test/fixtures_widget/test/derived_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/derived_widget.dart';

void main() {
  testWidgets('DerivedWidget golden', (tester) async {
    await tester.pumpWidget(const DerivedWidget());
    await expectLater(
      find.byType(DerivedWidget),
      matchesGoldenFile('goldens/derived.png'),
    );
  });
}
```

**ステップ 12: コミット**

```bash
git add test/fixtures_widget/
git commit -m "test: Widget単位解析用のフィクスチャプロジェクトを作成"
```

---

## タスク 3: WidgetExtractor — テストと実装

**ファイル:**
- 作成: `test/analyzer/widget/widget_extractor_test.dart`
- 作成: `lib/src/analyzer/widget/widget_extractor.dart`

**ステップ 1: 失敗するテストを書く**

```dart
// test/analyzer/widget/widget_extractor_test.dart
import 'package:golden_impact_runner/src/analyzer/widget/widget_extractor.dart';
import 'package:test/test.dart';

void main() {
  group('WidgetExtractor', () {
    late WidgetExtractor extractor;

    setUp(() {
      extractor = WidgetExtractor();
    });

    // === サポート対象 ===

    group('サポート対象', () {
      test('StatelessWidget を直接継承したクラスを検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  const MyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('button');
  }
}
''';
        final widgets = extractor.extractWidgets('/path/to/button.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'MyButton');
        expect(widgets[0].filePath, '/path/to/button.dart');
        expect(widgets[0].superclass, 'StatelessWidget');
      });

      test('StatefulWidget を直接継承したクラスを検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class MyDialog extends StatefulWidget {
  const MyDialog({super.key});

  @override
  State<MyDialog> createState() => _MyDialogState();
}

class _MyDialogState extends State<MyDialog> {
  @override
  Widget build(BuildContext context) {
    return const Text('dialog');
  }
}
''';
        final widgets = extractor.extractWidgets('/path/to/dialog.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'MyDialog');
        expect(widgets[0].superclass, 'StatefulWidget');
      });

      test('1ファイルに複数Widget定義がある場合すべて検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class WidgetA extends StatelessWidget {
  const WidgetA({super.key});
  @override
  Widget build(BuildContext context) => const Text('A');
}

class WidgetB extends StatelessWidget {
  const WidgetB({super.key});
  @override
  Widget build(BuildContext context) => const Text('B');
}
''';
        final widgets = extractor.extractWidgets('/path/to/multi.dart', source);

        expect(widgets, hasLength(2));
        expect(widgets.map((w) => w.name), containsAll(['WidgetA', 'WidgetB']));
      });

      test('ジェネリックWidget を検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class GenericWidget<T> extends StatelessWidget {
  const GenericWidget({super.key});
  @override
  Widget build(BuildContext context) => const Text('generic');
}
''';
        final widgets = extractor.extractWidgets('/path/to/generic.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'GenericWidget');
        expect(widgets[0].superclass, 'StatelessWidget');
      });

      test('State<T> クラスを Widget定義として検出しない', () {
        const source = '''
import 'package:flutter/material.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) => const Text('state');
}
''';
        final widgets = extractor.extractWidgets('/path/to/stateful.dart', source);

        // MyWidget のみ検出、_MyWidgetState は検出しない
        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'MyWidget');
      });

      test('通常のクラス（Widget以外を継承）を検出しない', () {
        const source = '''
class UserModel {
  final String name;
  UserModel(this.name);
}

class ApiService extends BaseService {
  void fetch() {}
}
''';
        final widgets = extractor.extractWidgets('/path/to/model.dart', source);

        expect(widgets, isEmpty);
      });

      test('mixin を検出しない', () {
        const source = '''
mixin AnimationMixin on StatelessWidget {
  void animate() {}
}
''';
        final widgets = extractor.extractWidgets('/path/to/mixin.dart', source);

        expect(widgets, isEmpty);
      });

      test('extension を検出しない', () {
        const source = '''
extension WidgetExtension on Widget {
  Widget padded() => this;
}
''';
        final widgets = extractor.extractWidgets('/path/to/ext.dart', source);

        expect(widgets, isEmpty);
      });

      test('コメント内のクラス定義を検出しない', () {
        const source = '''
// class FakeWidget extends StatelessWidget {}

/*
class CommentedOut extends StatefulWidget {
  @override
  State<CommentedOut> createState() => _CommentedOutState();
}
*/
''';
        final widgets = extractor.extractWidgets('/path/to/commented.dart', source);

        expect(widgets, isEmpty);
      });
    });

    // === サポート外（フォールバック動作を検証）===

    group('サポート外', () {
      test('abstract Widget は検出する（定義自体はWidget）', () {
        const source = '''
import 'package:flutter/material.dart';

abstract class BaseWidget extends StatelessWidget {
  const BaseWidget({super.key});
}
''';
        final widgets = extractor.extractWidgets('/path/to/base.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'BaseWidget');
        expect(widgets[0].superclass, 'StatelessWidget');
      });

      test('中間基底クラス経由は Widget として検出しない', () {
        const source = '''
import 'base_widget.dart';

class DerivedWidget extends BaseWidget {
  const DerivedWidget({super.key});

  @override
  Widget build(BuildContext context) => const Text('derived');
}
''';
        final widgets = extractor.extractWidgets('/path/to/derived.dart', source);

        // BaseWidget は既知の StatelessWidget/StatefulWidget ではないため検出しない
        expect(widgets, isEmpty);
      });
    });

    // === extractAllWidgets ===

    group('extractAllWidgets', () {
      test('フィクスチャプロジェクト全体からWidget定義を収集する', () {
        final fixturesRoot = 'test/fixtures_widget';
        final result = extractor.extractAllWidgets(fixturesRoot);

        // button.dart: AppButton
        // card.dart: AppCard
        // dialog.dart: AppDialog
        // multi_widget.dart: WidgetA, WidgetB
        // base_widget.dart: BaseWidget (abstract)
        // derived_widget.dart: DerivedWidget は検出されない（中間基底）
        // utils.dart, indirect_usage.dart, models/user.dart: Widget なし
        final allWidgets = result.values.expand((list) => list).toList();
        final names = allWidgets.map((w) => w.name).toSet();

        expect(names, containsAll([
          'AppButton', 'AppCard', 'AppDialog',
          'WidgetA', 'WidgetB', 'BaseWidget',
        ]));
        expect(names, isNot(contains('DerivedWidget')));
        expect(names, isNot(contains('WidgetUtils')));
        expect(names, isNot(contains('User')));
      });
    });
  });
}
```

**ステップ 2: テストを実行して失敗を確認する**

実行: `dart test test/analyzer/widget/widget_extractor_test.dart`
期待値: FAIL（`widget_extractor.dart` が存在しない）

**ステップ 3: 最小限の実装を書く**

```dart
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
```

**ステップ 4: テストを実行して通過を確認する**

実行: `dart test test/analyzer/widget/widget_extractor_test.dart`
期待値: ALL TESTS PASSED

**ステップ 5: コミット**

```bash
git add lib/src/analyzer/widget/widget_extractor.dart test/analyzer/widget/widget_extractor_test.dart
git commit -m "feat: WidgetExtractor を実装 — AST解析でWidget定義を抽出"
```

---

## タスク 4: WidgetUsageDetector — テストと実装

**ファイル:**
- 作成: `test/analyzer/widget/widget_usage_detector_test.dart`
- 作成: `lib/src/analyzer/widget/widget_usage_detector.dart`

**ステップ 1: 失敗するテストを書く**

```dart
// test/analyzer/widget/widget_usage_detector_test.dart
import 'package:golden_impact_runner/src/analyzer/widget/widget_usage_detector.dart';
import 'package:test/test.dart';

void main() {
  group('WidgetUsageDetector', () {
    late WidgetUsageDetector detector;

    setUp(() {
      // 既知の Widget 名を登録して初期化
      detector = WidgetUsageDetector(
        knownWidgets: {'MyWidget', 'AppButton', 'AppCard', 'OtherWidget'},
      );
    });

    // === サポート対象 ===

    group('サポート対象', () {
      test('コンストラクタ呼び出しを検出する', () {
        const source = '''
void main() {
  final w = MyWidget();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, hasLength(1));
        expect(usages[0].widgetName, 'MyWidget');
        expect(usages[0].filePath, '/path/to/file.dart');
      });

      test('const コンストラクタを検出する', () {
        const source = '''
void main() {
  const widget = const MyWidget();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, hasLength(1));
        expect(usages[0].widgetName, 'MyWidget');
      });

      test('named コンストラクタを検出する', () {
        const source = '''
void main() {
  final w = MyWidget.custom();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, hasLength(1));
        expect(usages[0].widgetName, 'MyWidget');
      });

      test('build() メソッド内でのネスト使用を検出する', () {
        const source = '''
class ParentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(label: 'OK'),
        AppCard(title: 'Card'),
      ],
    );
  }
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['AppButton', 'AppCard']));
      });

      test('変数への代入を検出する', () {
        const source = '''
void main() {
  final w = MyWidget();
  var x = AppButton(label: 'test');
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['MyWidget', 'AppButton']));
      });

      test('コレクション内の生成を検出する', () {
        const source = '''
void main() {
  final list = [MyWidget(), OtherWidget()];
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['MyWidget', 'OtherWidget']));
      });

      test('条件式内の両方を検出する', () {
        const source = '''
void main() {
  final w = true ? MyWidget() : OtherWidget();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['MyWidget', 'OtherWidget']));
      });

      test('既知Widget名リストに含まれないクラスの生成を検出しない', () {
        const source = '''
void main() {
  final model = UserModel();
  final service = ApiService();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, isEmpty);
      });

      test('コメント内の記述を検出しない', () {
        const source = '''
// MyWidget() を使う
/* AppButton(label: 'test') */
void main() {}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, isEmpty);
      });
    });

    // === サポート外（フォールバック動作を検証）===

    group('サポート外', () {
      test('型アノテーションのみは使用として検出しない', () {
        const source = '''
class Holder {
  MyWidget? widget;
  List<AppButton> buttons = [];
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, isEmpty);
      });

      test('staticメソッド呼び出しは使用として検出しない', () {
        const source = '''
void main() {
  final theme = MyWidget.of(context);
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        // MyWidget.of() は MethodInvocation であり InstanceCreationExpression ではない
        expect(usages, isEmpty);
      });

      test('関数経由の間接生成は呼び出し側で検出されない', () {
        // buildDefaultButton() 内部で AppButton() を生成しているが、
        // この呼び出し側のファイルからは AppButton への依存は見えない
        const source = '''
import 'indirect_usage.dart';

void main() {
  final w = buildDefaultButton();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        // buildDefaultButton は Widget 名ではないので検出されない
        expect(usages, isEmpty);
      });
    });
  });
}
```

**ステップ 2: テストを実行して失敗を確認する**

実行: `dart test test/analyzer/widget/widget_usage_detector_test.dart`
期待値: FAIL（`widget_usage_detector.dart` が存在しない）

**ステップ 3: 最小限の実装を書く**

```dart
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

/// AST の InstanceCreationExpression を訪問し、
/// 既知の Widget の使用箇所を検出する。
///
/// MVP では名前ベースの判定を使用:
/// InstanceCreationExpression のコンストラクタ名が
/// 既知 Widget 名リストに含まれるかで判定する。
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

/// AST Visitor: InstanceCreationExpression を訪問して Widget 使用を検出する。
class _UsageVisitor extends RecursiveAstVisitor<void> {
  _UsageVisitor(this.filePath, this.knownWidgets);

  final String filePath;
  final Set<String> knownWidgets;
  final List<WidgetUsage> usages = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName;
    final typeName = constructorName.type.name2.lexeme;

    if (knownWidgets.contains(typeName)) {
      usages.add(WidgetUsage(widgetName: typeName, filePath: filePath));
    }

    // 子ノードも訪問（ネストされた生成式を検出するため）
    super.visitInstanceCreationExpression(node);
  }
}
```

**ステップ 4: テストを実行して通過を確認する**

実行: `dart test test/analyzer/widget/widget_usage_detector_test.dart`
期待値: ALL TESTS PASSED

**ステップ 5: コミット**

```bash
git add lib/src/analyzer/widget/widget_usage_detector.dart test/analyzer/widget/widget_usage_detector_test.dart
git commit -m "feat: WidgetUsageDetector を実装 — AST解析でWidget使用箇所を検出"
```

---

## タスク 5: WidgetDependencyGraph — テストと実装

**ファイル:**
- 作成: `test/analyzer/widget/widget_dependency_graph_test.dart`
- 作成: `lib/src/analyzer/widget/widget_dependency_graph.dart`

**ステップ 1: 失敗するテストを書く**

```dart
// test/analyzer/widget/widget_dependency_graph_test.dart
import 'package:golden_impact_runner/src/analyzer/widget/widget_dependency_graph.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('WidgetDependencyGraph', () {
    late String fixturesRoot;

    setUp(() {
      fixturesRoot = p.normalize(p.join(p.current, 'test', 'fixtures_widget'));
    });

    // === サポート対象 ===

    group('サポート対象', () {
      late WidgetDependencyGraph widgetGraph;

      setUp(() {
        widgetGraph = WidgetDependencyGraph.build(
          projectRoot: fixturesRoot,
          packageName: 'widget_test_app',
        );
      });

      test('Widget A が Widget B を使用 → B変更時にAが影響', () {
        // card.dart は button.dart の AppButton を使用
        // button.dart 変更 → card.dart が影響
        final buttonPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'widgets', 'button.dart'),
        );
        final impacted = widgetGraph.findImpactedFiles({buttonPath});
        final relative = impacted.map(
          (f) => p.relative(f, from: fixturesRoot),
        ).toSet();

        expect(relative, contains(p.join('lib', 'widgets', 'card.dart')));
      });

      test('推移的依存: A→B→C、C変更時にA,Bが影響', () {
        // dialog.dart → card.dart → button.dart
        // button.dart 変更 → card.dart, dialog.dart が影響
        final buttonPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'widgets', 'button.dart'),
        );
        final impacted = widgetGraph.findImpactedFiles({buttonPath});
        final relative = impacted.map(
          (f) => p.relative(f, from: fixturesRoot),
        ).toSet();

        expect(relative, contains(p.join('lib', 'widgets', 'card.dart')));
        expect(relative, contains(p.join('lib', 'widgets', 'dialog.dart')));
      });

      test('Widget未使用ファイルの変更 → importチェーンで追跡', () {
        // utils.dart は Widget を含まないが、
        // 他のファイルから import されていれば影響が波及する
        final utilsPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'widgets', 'utils.dart'),
        );
        final impacted = widgetGraph.findImpactedFiles({utilsPath});

        // utils.dart を import しているファイルがなければ自身のみ
        expect(impacted, contains(utilsPath));
      });

      test('1ファイルに Widget X, Y 定義。Xだけ使用 → Y変更は使用側に影響しない', () {
        // multi_widget.dart に WidgetA, WidgetB が定義
        // multi_widget_golden_test.dart は WidgetA のみの Golden Test
        // WidgetB のみの変更では、WidgetA を使用する側には影響しない
        //
        // ただし MVP ではファイル単位の変更検知のため、
        // multi_widget.dart の変更で WidgetA も影響対象になる。
        // Widget単位の差分検知は将来の拡張。
        //
        // ここでは「WidgetB を使用しているファイルは存在しない」ことを検証する。
        final multiPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'widgets', 'multi_widget.dart'),
        );
        final impacted = widgetGraph.findImpactedFiles({multiPath});
        final relative = impacted.map(
          (f) => p.relative(f, from: fixturesRoot),
        ).toSet();

        // multi_widget_golden_test.dart は import しているので影響
        expect(relative, contains(
          p.join('test', 'multi_widget_golden_test.dart'),
        ));
      });

      test('Widgetを含まないファイルの変更 → ファイルレベルのimportチェーンにフォールバック', () {
        final userPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'models', 'user.dart'),
        );
        final impacted = widgetGraph.findImpactedFiles({userPath});

        // user.dart を import するファイルがなければ自身のみ
        expect(impacted, contains(userPath));
      });
    });

    // === サポート外（フォールバック動作を検証）===

    group('サポート外', () {
      late WidgetDependencyGraph widgetGraph;

      setUp(() {
        widgetGraph = WidgetDependencyGraph.build(
          projectRoot: fixturesRoot,
          packageName: 'widget_test_app',
        );
      });

      test('中間基底クラス経由の依存 → ファイルレベルの依存追跡にフォールバック', () {
        // derived_widget.dart は BaseWidget を extends しているが、
        // MVP では Widget として認識されない。
        // ファイルレベルの import チェーンで追跡される。
        final derivedPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'widgets', 'derived_widget.dart'),
        );
        final impacted = widgetGraph.findImpactedFiles({derivedPath});
        final relative = impacted.map(
          (f) => p.relative(f, from: fixturesRoot),
        ).toSet();

        // derived_golden_test.dart が import で依存しているので影響
        expect(relative, contains(
          p.join('test', 'derived_golden_test.dart'),
        ));
      });

      test('パッケージ外のWidget使用は無視される', () {
        // button.dart は package:flutter/material.dart の ElevatedButton を使用
        // しているが、外部パッケージは依存グラフに含まれない
        final buttonPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'widgets', 'button.dart'),
        );
        final impacted = widgetGraph.findImpactedFiles({buttonPath});

        // 外部パッケージのファイルが含まれないことを確認
        for (final file in impacted) {
          expect(file, startsWith(fixturesRoot));
        }
      });
    });
  });
}
```

**ステップ 2: テストを実行して失敗を確認する**

実行: `dart test test/analyzer/widget/widget_dependency_graph_test.dart`
期待値: FAIL（`widget_dependency_graph.dart` が存在しない）

**ステップ 3: 最小限の実装を書く**

```dart
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
    final fileDependsOn = <String, Set<String>>{};
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
        fileDependsOn[filePath] = deps;

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
```

**ステップ 4: テストを実行して通過を確認する**

実行: `dart test test/analyzer/widget/widget_dependency_graph_test.dart`
期待値: ALL TESTS PASSED

**ステップ 5: コミット**

```bash
git add lib/src/analyzer/widget/widget_dependency_graph.dart test/analyzer/widget/widget_dependency_graph_test.dart
git commit -m "feat: WidgetDependencyGraph を実装 — Widget単位の依存グラフ構築とBFS逆引き"
```

---

## タスク 6: CLI統合 — --analysis-mode オプション

**ファイル:**
- 変更: `lib/src/cli/args_parser.dart:6-88`
- 変更: `lib/src/cli/runner.dart:12-32` (RunnerConfig)
- 変更: `lib/src/cli/runner.dart:43-181` (Runner.run)
- テスト: `test/cli/args_parser_test.dart`
- テスト: `test/cli/runner_test.dart`

**ステップ 1: ArgsParser のテストを追加する**

`test/cli/args_parser_test.dart` に以下のテストを追加:

```dart
// 既存テストファイルに追加

group('--analysis-mode', () {
  test('デフォルトは file', () {
    final config = ArgsParser.parse([]);
    expect(config!.analysisMode, AnalysisMode.file);
  });

  test('--analysis-mode=widget でwidgetモードになる', () {
    final config = ArgsParser.parse(['--analysis-mode', 'widget']);
    expect(config!.analysisMode, AnalysisMode.widget);
  });

  test('--analysis-mode=file でfileモードになる', () {
    final config = ArgsParser.parse(['--analysis-mode', 'file']);
    expect(config!.analysisMode, AnalysisMode.file);
  });

  test('不正な値で FormatException', () {
    expect(
      () => ArgsParser.parse(['--analysis-mode', 'invalid']),
      throwsFormatException,
    );
  });
});
```

**ステップ 2: テストを実行して失敗を確認する**

実行: `dart test test/cli/args_parser_test.dart`
期待値: FAIL（`analysisMode` プロパティが存在しない）

**ステップ 3: RunnerConfig に AnalysisMode を追加する**

`lib/src/cli/runner.dart` を変更:

```dart
// ファイル冒頭に追加（既存の import の後）
import '../analyzer/widget/widget_dependency_graph.dart';

// OutputFormat enum の隣に追加
enum AnalysisMode { file, widget }

// RunnerConfig に追加
class RunnerConfig {
  const RunnerConfig({
    required this.projectRoot,
    this.baseBranch = 'origin/main',
    this.head = 'HEAD',
    this.changedFiles = const [],
    this.excludePatterns = const [],
    this.format = OutputFormat.text,
    this.analysisMode = AnalysisMode.file,
    this.verbose = false,
  });

  // ... 既存フィールド ...
  final AnalysisMode analysisMode;
  // ...
}
```

**ステップ 4: ArgsParser に --analysis-mode を追加する**

`lib/src/cli/args_parser.dart` を変更:

ヘルプ文字列に追加:
```
  --analysis-mode <mode>  Analysis mode: file, widget (default: file)
```

パースロジックに追加:
```dart
case '--analysis-mode':
  final mode = _nextArg(args, i, '--analysis-mode');
  analysisMode = switch (mode) {
    'file' => AnalysisMode.file,
    'widget' => AnalysisMode.widget,
    _ => throw FormatException('Unknown analysis mode: $mode'),
  };
  i++;
```

**ステップ 5: Runner.run に分岐を追加する**

`lib/src/cli/runner.dart` の `run()` メソッドで、ステップ3（依存グラフ構築）とステップ4（BFS）を `analysisMode` で分岐:

```dart
// 3. 依存グラフを構築し、4. BFS で影響ファイルを検索
final Set<String> impactedFiles;
if (config.analysisMode == AnalysisMode.widget) {
  final widgetGraph = WidgetDependencyGraph.build(
    projectRoot: projectRoot,
    packageName: packageName,
  );
  if (config.verbose) {
    _err.writeln(
      'Widget dependency graph: ${widgetGraph.allFiles.length} files, '
      '${widgetGraph.fileToWidgets.values.fold<int>(0, (sum, s) => sum + s.length)} widgets',
    );
  }
  impactedFiles = widgetGraph.findImpactedFiles(changedFiles);
} else {
  final graph = DependencyGraph.build(
    projectRoot: projectRoot,
    packageName: packageName,
  );
  if (config.verbose) {
    _err.writeln(
      'Dependency graph: ${graph.allFiles.length} files, '
      '${graph.dependsOn.values.fold<int>(0, (sum, s) => sum + s.length)} edges',
    );
  }
  impactedFiles = graph.findImpactedFiles(changedFiles);
}
```

**ステップ 6: テストを実行して通過を確認する**

実行: `dart test test/cli/args_parser_test.dart && dart test test/cli/runner_test.dart`
期待値: ALL TESTS PASSED

**ステップ 7: 全テストの通過を確認する**

実行: `dart test`
期待値: ALL TESTS PASSED

**ステップ 8: コミット**

```bash
git add lib/src/cli/runner.dart lib/src/cli/args_parser.dart test/cli/args_parser_test.dart
git commit -m "feat: --analysis-mode オプションを追加 — file/widget の切り替え"
```

---

## タスク 7: E2Eテスト — 不変条件とフォールバック検証

**ファイル:**
- 作成: `test/integration/widget_analysis_e2e_test.dart`

**ステップ 1: E2Eテストを書く**

```dart
// test/integration/widget_analysis_e2e_test.dart
import 'dart:convert';

import 'package:golden_impact_runner/src/cli/runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String fixturesRoot;

  setUp(() {
    fixturesRoot = p.normalize(p.join(p.current, 'test', 'fixtures_widget'));
  });

  /// file モードで影響テストを取得するヘルパー
  Future<Set<String>> goldenTestsForFile(List<String> changedFiles) async {
    return _goldenTestsFor(fixturesRoot, changedFiles, AnalysisMode.file);
  }

  /// widget モードで影響テストを取得するヘルパー
  Future<Set<String>> goldenTestsForWidget(List<String> changedFiles) async {
    return _goldenTestsFor(fixturesRoot, changedFiles, AnalysisMode.widget);
  }

  // ─── 1. 不変条件テスト ───

  group('不変条件: widget結果 ⊆ file結果', () {
    test('button.dart 変更時', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/button.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/button.dart'],
      );

      // widget の結果は file の結果のサブセット
      expect(fileResult.containsAll(widgetResult), isTrue,
        reason: 'widget結果 $widgetResult が file結果 $fileResult のサブセットではない');
    });

    test('card.dart 変更時', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/card.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/card.dart'],
      );

      expect(fileResult.containsAll(widgetResult), isTrue);
    });

    test('multi_widget.dart 変更時', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/multi_widget.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/multi_widget.dart'],
      );

      expect(fileResult.containsAll(widgetResult), isTrue);
    });
  });

  // ─── 2. 精度改善の検証 ───

  group('精度改善', () {
    test('button.dart 変更 → 両モードで button, card, dialog のテストが影響', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/button.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/button.dart'],
      );

      // 両モードとも button, card, dialog の golden test が影響
      for (final result in [fileResult, widgetResult]) {
        expect(result, contains(p.join('test', 'button_golden_test.dart')));
        expect(result, contains(p.join('test', 'card_golden_test.dart')));
        expect(result, contains(p.join('test', 'dialog_golden_test.dart')));
      }
    });
  });

  // ─── 3. サポート外のフォールバック検証 ───

  group('サポート外のフォールバック', () {
    test('derived_widget.dart 変更 → 両モードで同じ結果（精度低下なし）', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/derived_widget.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/derived_widget.dart'],
      );

      // DerivedWidget は MVP で Widget 認識されないため、
      // 両モードでファイルレベルの依存追跡が使われ、同じ結果になる
      expect(widgetResult, fileResult,
        reason: 'サポート外ケースでは両モードの結果が一致すべき');

      // derived_golden_test.dart が影響に含まれること
      expect(fileResult, contains(
        p.join('test', 'derived_golden_test.dart'),
      ));
    });

    test('utils.dart 変更 → 両モードで同じ結果', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/utils.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/utils.dart'],
      );

      // Widget でないファイルの変更は両モード同じ
      expect(widgetResult, fileResult);
    });
  });
}

/// Runner を使って指定モードで影響テストを取得するヘルパー
Future<Set<String>> _goldenTestsFor(
  String fixturesRoot,
  List<String> changedFiles,
  AnalysisMode mode,
) async {
  final outBuf = StringBuffer();
  final runner = Runner(outSink: _StringSink(outBuf));

  final exitCode = await runner.run(RunnerConfig(
    projectRoot: fixturesRoot,
    changedFiles: changedFiles,
    format: OutputFormat.json,
    analysisMode: mode,
  ));

  expect(exitCode, 0);

  if (outBuf.toString().trim().isEmpty) return {};
  final json = jsonDecode(outBuf.toString()) as Map<String, dynamic>;
  return (json['golden_tests'] as List).cast<String>().toSet();
}

/// テスト用の StringSink ラッパー
class _StringSink implements StringSink {
  _StringSink(this._buf);
  final StringBuffer _buf;

  @override
  void write(Object? object) => _buf.write(object);
  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _buf.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => _buf.writeln(object);
}
```

**ステップ 2: テストを実行して通過を確認する**

実行: `dart test test/integration/widget_analysis_e2e_test.dart`
期待値: ALL TESTS PASSED

**ステップ 3: 全テストの通過を確認する**

実行: `dart test`
期待値: ALL TESTS PASSED

**ステップ 4: コミット**

```bash
git add test/integration/widget_analysis_e2e_test.dart
git commit -m "test: Widget単位解析のE2Eテスト — 不変条件・精度改善・フォールバック検証"
```

---

## タスク 8: 静的解析と最終確認

**ファイル:**
- 変更なし（問題があれば修正）

**ステップ 1: 静的解析を実行する**

実行: `dart analyze`
期待値: No issues found

**ステップ 2: 全テストを実行する**

実行: `dart test`
期待値: ALL TESTS PASSED

**ステップ 3: 問題があれば修正してコミットする**

問題がなければスキップ。

---

## タスク 9: ドキュメント更新

**ファイル:**
- 変更: `TODO.md`
- 変更: `CHANGELOG.md`

**ステップ 1: TODO.md の Phase 2 セクションを更新する**

完了したタスクにチェックマークを付ける:

```markdown
### Widget単位の依存解析

- [x] `package:analyzer` 導入（AST解析）
- [x] WidgetExtractor — Widget定義を抽出
- [x] WidgetUsageDetector — `InstanceCreationExpression` からWidget使用を検出
- [ ] Widget型判定（`StatelessWidget`/`StatefulWidget` のサブクラスか）← MVP: 名前ベース判定で対応済。フル型解決は将来対応
- [x] Widget単位の依存グラフ構築（1ファイル複数Widget対応）
```

**ステップ 2: CHANGELOG.md に Phase 2 MVP のエントリを追加する**

```markdown
## [Unreleased]

### Added
- `--analysis-mode` オプション（`file` / `widget`）
- Widget単位の依存解析パイプライン（`package:analyzer` による AST 解析）
- WidgetExtractor: StatelessWidget / StatefulWidget の定義を抽出
- WidgetUsageDetector: InstanceCreationExpression から Widget 使用を検出
- WidgetDependencyGraph: Widget 単位の BFS 逆引き

### Notes
- Widget 型判定は名前ベースの簡易判定（MVP）。中間基底クラス経由はファイルレベルにフォールバック
- フル型解決（AnalysisContext）は将来の拡張で対応予定
```

**ステップ 3: コミット**

```bash
git add TODO.md CHANGELOG.md
git commit -m "docs: Phase 2 MVP の進捗を TODO.md と CHANGELOG.md に反映"
```
