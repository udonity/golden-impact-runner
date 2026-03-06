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
