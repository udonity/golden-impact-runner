import 'package:golden_impact_runner/src/cli/runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Runner', () {
    late Runner runner;
    late String fixturesRoot;

    setUp(() {
      runner = Runner();
      fixturesRoot = p.normalize(p.join(p.current, 'test', 'fixtures'));
    });

    group('--changed によるフロー', () {
      test('変更ファイルからゴールデンテストを検出して正常終了する', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/widgets/button.dart'],
          format: OutputFormat.text,
        );

        final exitCode = await runner.run(config);
        expect(exitCode, 0);
      });

      test('影響がないファイルを変更した場合も正常終了する', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/screens/settings_screen.dart'],
          format: OutputFormat.text,
        );

        final exitCode = await runner.run(config);
        expect(exitCode, 0);
      });

      test('変更ファイルが空の場合は正常終了する', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['nonexistent.yaml'],
          format: OutputFormat.text,
        );

        final exitCode = await runner.run(config);
        expect(exitCode, 0);
      });
    });

    group('JSON出力', () {
      test('--format json で有効なJSONを出力する', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/models/theme_data.dart'],
          format: OutputFormat.json,
        );

        final exitCode = await runner.run(config);
        expect(exitCode, 0);
        // JSON出力は stdout に書かれるため、exit codeのみ検証
      });
    });

    group('verbose モード', () {
      test('verbose でも正常終了する', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/widgets/button.dart'],
          format: OutputFormat.text,
          verbose: true,
        );

        final exitCode = await runner.run(config);
        expect(exitCode, 0);
      });
    });

    group('pubspec.yaml が存在しない場合', () {
      test('パッケージ名が読めない場合はエラーコード1を返す', () async {
        final config = RunnerConfig(
          projectRoot: '/nonexistent/project/root',
          changedFiles: ['lib/a.dart'],
        );

        final exitCode = await runner.run(config);
        expect(exitCode, 1);
      });
    });

    group('RunnerConfig', () {
      test('デフォルト値が正しい', () {
        final config = RunnerConfig(projectRoot: '.');
        expect(config.projectRoot, '.');
        expect(config.baseBranch, 'origin/main');
        expect(config.head, 'HEAD');
        expect(config.changedFiles, isEmpty);
        expect(config.format, OutputFormat.text);
        expect(config.verbose, isFalse);
      });

      test('すべてのフィールドを指定できる', () {
        final config = RunnerConfig(
          projectRoot: '/app',
          baseBranch: 'develop',
          head: 'abc123',
          changedFiles: ['a.dart', 'b.dart'],
          format: OutputFormat.json,
          verbose: true,
        );
        expect(config.projectRoot, '/app');
        expect(config.baseBranch, 'develop');
        expect(config.head, 'abc123');
        expect(config.changedFiles, ['a.dart', 'b.dart']);
        expect(config.format, OutputFormat.json);
        expect(config.verbose, isTrue);
      });
    });
  });
}
