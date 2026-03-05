import 'dart:convert';
import 'dart:io';

import 'package:golden_impact_runner/src/analyzer/dependency_graph.dart';
import 'package:golden_impact_runner/src/analyzer/golden_test_detector.dart';
import 'package:golden_impact_runner/src/cli/runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String fixturesRoot;
  late DependencyGraph graph;
  late GoldenTestDetector detector;

  setUp(() {
    fixturesRoot = p.normalize(p.join(p.current, 'test', 'fixtures'));
    graph = DependencyGraph.build(
      projectRoot: fixturesRoot,
      packageName: 'test_app',
    );
    detector = GoldenTestDetector(fixturesRoot);
  });

  Set<String> goldenTestsFor(Set<String> changedFiles) {
    final impacted = graph.findImpactedFiles(changedFiles);
    return detector.filterGoldenTests(impacted).map(
      (f) => p.relative(f, from: fixturesRoot),
    ).toSet();
  }

  String absFixture(String relativePath) {
    return p.normalize(p.join(fixturesRoot, relativePath));
  }

  // ─── 1. 推移的依存の追跡 ───

  group('推移的依存', () {
    test('theme_data.dart の変更が button と home_screen の golden test に波及する',
        () {
      final result = goldenTestsFor({
        absFixture('lib/src/models/theme_data.dart'),
      });

      expect(result, containsAll([
        p.join('test', 'widgets', 'button_golden_test.dart'),
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ]));
    });
  });

  // ─── 2. 直接依存の追跡 ───

  group('直接依存', () {
    test('button.dart の変更が button, home_screen, all_widgets の golden test に波及する',
        () {
      final result = goldenTestsFor({
        absFixture('lib/src/widgets/button.dart'),
      });

      expect(result, containsAll([
        p.join('test', 'widgets', 'button_golden_test.dart'),
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ]));
    });
  });

  // ─── 3. 無関係なファイル変更 → 影響ゼロ ───

  group('影響範囲の限定', () {
    test('settings_screen.dart の変更は golden test に影響しない', () {
      final result = goldenTestsFor({
        absFixture('lib/src/screens/settings_screen.dart'),
      });

      expect(result, isEmpty);
    });

    test('非 golden test (settings_screen_test) は golden test 結果に含まれない', () {
      // settings_screen_test は settings_screen を import しているので
      // impacted には含まれるが、golden test ではないので最終結果には含まれない
      final result = goldenTestsFor({
        absFixture('lib/src/screens/settings_screen.dart'),
      });

      expect(result, isNot(contains(
        p.join('test', 'screens', 'settings_screen_test.dart'),
      )));
    });
  });

  // ─── 4. 複数ファイル同時変更 ───

  group('複数ファイル同時変更', () {
    test('settings_screen + button の同時変更で影響範囲が合算される', () {
      final result = goldenTestsFor({
        absFixture('lib/src/screens/settings_screen.dart'),
        absFixture('lib/src/widgets/button.dart'),
      });

      // button 経由の影響のみ（settings_screen には golden test がない）
      expect(result, containsAll([
        p.join('test', 'widgets', 'button_golden_test.dart'),
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ]));
    });

    test('theme_data + home_screen の同時変更で重複なく合算される', () {
      final result = goldenTestsFor({
        absFixture('lib/src/models/theme_data.dart'),
        absFixture('lib/src/screens/home_screen.dart'),
      });

      // 両方の経路から到達するが、結果は重複なし
      expect(result, containsAll([
        p.join('test', 'widgets', 'button_golden_test.dart'),
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ]));
    });
  });

  // ─── 5. export (barrel) 経由の依存追跡 ───

  group('export (barrel) 経由の依存', () {
    test('widgets.dart barrel を変更すると経由先の golden test に波及する', () {
      final result = goldenTestsFor({
        absFixture('lib/src/widgets/widgets.dart'),
      });

      // widgets.dart を変更 → all_widgets_golden_test が影響を受ける
      expect(result, contains(
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ));
    });

    test('button.dart の変更が barrel 経由の golden test にも波及する', () {
      final result = goldenTestsFor({
        absFixture('lib/src/widgets/button.dart'),
      });

      // button → widgets.dart (export) → all_widgets_golden_test
      expect(result, contains(
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ));
    });
  });

  // ─── 6. テストファイル自体の変更 ───

  group('テストファイル自体の変更', () {
    test('golden test ファイルを直接変更すると自身が結果に含まれる', () {
      final result = goldenTestsFor({
        absFixture('test/widgets/button_golden_test.dart'),
      });

      expect(result, contains(
        p.join('test', 'widgets', 'button_golden_test.dart'),
      ));
    });

    test('非 golden test ファイルを変更しても結果に含まれない', () {
      final result = goldenTestsFor({
        absFixture('test/screens/settings_screen_test.dart'),
      });

      expect(result, isEmpty);
    });
  });

  // ─── 7. package: import の解決 ───

  group('package: import の解決', () {
    test('package:test_app/ 形式の import が正しく依存追跡される', () {
      // button_golden_test.dart は package:test_app/src/widgets/button.dart
      // を import しているので、button.dart の変更で影響を受ける
      final impacted = graph.findImpactedFiles({
        absFixture('lib/src/widgets/button.dart'),
      });
      final relative = impacted.map(
        (f) => p.relative(f, from: fixturesRoot),
      ).toSet();

      expect(relative, contains(
        p.join('test', 'widgets', 'button_golden_test.dart'),
      ));
    });
  });

  // ─── 8. Runner の出力内容検証 ───

  group('Runner 出力内容検証', () {
    test('テキスト出力が影響のある golden test パスのみを含む', () async {
      final output = await _captureStdout(() async {
        final runner = Runner();
        return runner.run(RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/widgets/button.dart'],
          format: OutputFormat.text,
        ));
      });

      final lines = output.trim().split('\n').where((l) => l.isNotEmpty).toSet();

      expect(lines, containsAll([
        p.join('test', 'widgets', 'button_golden_test.dart'),
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ]));
      // settings_screen_test は含まれない
      expect(lines, isNot(contains(
        p.join('test', 'screens', 'settings_screen_test.dart'),
      )));
    });

    test('JSON 出力が正しい構造とデータを持つ', () async {
      final output = await _captureStdout(() async {
        final runner = Runner();
        return runner.run(RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/models/theme_data.dart'],
          format: OutputFormat.json,
        ));
      });

      final json = jsonDecode(output) as Map<String, dynamic>;

      // 3つのキーが存在する
      expect(json, containsPair('changed_files', isList));
      expect(json, containsPair('impacted_files', isList));
      expect(json, containsPair('golden_tests', isList));

      // changed_files は指定した1ファイル
      expect(json['changed_files'], [
        p.join('lib', 'src', 'models', 'theme_data.dart'),
      ]);

      // golden_tests に期待するテストが含まれる
      final goldenTests = (json['golden_tests'] as List).cast<String>();
      expect(goldenTests, containsAll([
        p.join('test', 'widgets', 'button_golden_test.dart'),
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
        p.join('test', 'widgets', 'all_widgets_golden_test.dart'),
      ]));

      // impacted_files は golden_tests のスーパーセット
      final impactedFiles = (json['impacted_files'] as List).cast<String>();
      for (final gt in goldenTests) {
        expect(impactedFiles, contains(gt));
      }
    });

    test('影響ゼロの場合テキスト出力が空になる', () async {
      final output = await _captureStdout(() async {
        final runner = Runner();
        return runner.run(RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/screens/settings_screen.dart'],
          format: OutputFormat.text,
        ));
      });

      expect(output.trim(), isEmpty);
    });

    test('影響ゼロの場合JSON出力の golden_tests が空配列になる', () async {
      final output = await _captureStdout(() async {
        final runner = Runner();
        return runner.run(RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/screens/settings_screen.dart'],
          format: OutputFormat.json,
        ));
      });

      final json = jsonDecode(output) as Map<String, dynamic>;
      expect(json['golden_tests'], isEmpty);
      expect(json['changed_files'], isNotEmpty);
    });
  });
}

/// stdout をキャプチャするヘルパー
Future<String> _captureStdout(Future<int> Function() action) async {
  final buffer = StringBuffer();
  final spec = StringSinkIOOverrides(buffer);
  return IOOverrides.runZoned(
    () async {
      await action();
      return buffer.toString();
    },
    stdout: () => spec,
  );
}

/// stdout を StringBuffer にリダイレクトする IOOverrides 用の Stdout 実装
class StringSinkIOOverrides implements Stdout {
  StringSinkIOOverrides(this._buffer);
  final StringBuffer _buffer;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void writeAll(Iterable objects, [String sep = '']) =>
      _buffer.writeAll(objects, sep);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void add(List<int> data) => _buffer.write(String.fromCharCodes(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      throw UnsupportedError('addError');

  @override
  Future addStream(Stream<List<int>> stream) =>
      throw UnsupportedError('addStream');

  @override
  Future flush() async {}

  @override
  Future close() async {}

  @override
  Future get done => Future.value();

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  bool get hasTerminal => false;

  @override
  IOSink get nonBlocking => this;

  @override
  int get terminalColumns => 80;

  @override
  int get terminalLines => 24;

  @override
  bool get supportsAnsiEscapes => false;

  @override
  String get lineTerminator => '\n';

  @override
  set lineTerminator(String value) {}
}
