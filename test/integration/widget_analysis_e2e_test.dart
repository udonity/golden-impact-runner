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
    test('button.dart 変更 → 両モードとも Widget 使用チェーンの golden test が影響', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/button.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/button.dart'],
      );

      // 両モードとも AppButton を使っている golden test は影響
      for (final result in [fileResult, widgetResult]) {
        expect(result, contains(p.join('test', 'button_golden_test.dart')));
        expect(result, contains(p.join('test', 'card_golden_test.dart')));
        expect(result, contains(p.join('test', 'dialog_golden_test.dart')));
      }
    });

    test('button.dart 変更 → widget モードは import のみで Widget 未使用のテストを除外', () async {
      final fileResult = await goldenTestsForFile(
        ['lib/widgets/button.dart'],
      );
      final widgetResult = await goldenTestsForWidget(
        ['lib/widgets/button.dart'],
      );

      final constantsTest = p.join('test', 'button_constants_golden_test.dart');

      // file モード: button_constants.dart は button.dart を import → 影響に含まれる
      expect(fileResult, contains(constantsTest),
        reason: 'file モードでは import チェーンで button_constants_golden_test が影響に含まれるべき');

      // widget モード: button.dart は Widget 定義を持つため Widget エッジのみ伝搬。
      // button_constants.dart は AppButton を使っていないため影響から除外される
      expect(widgetResult, isNot(contains(constantsTest)),
        reason: 'widget モードでは Widget 未使用の button_constants_golden_test は除外されるべき');

      // widget 結果は file 結果の真部分集合
      expect(widgetResult.length, lessThan(fileResult.length),
        reason: 'widget モードは file モードより少ない結果を返すべき');
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
