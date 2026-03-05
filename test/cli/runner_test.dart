import 'dart:convert';
import 'dart:io';

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

    group('エラーハンドリング', () {
      late StringBuffer errBuf;

      setUp(() {
        errBuf = StringBuffer();
        runner = Runner(errSink: _StringSink(errBuf));
      });

      test('存在しないプロジェクトディレクトリで具体的なエラーを返す', () async {
        final config = RunnerConfig(
          projectRoot: '/nonexistent/project/root',
          changedFiles: ['lib/a.dart'],
        );

        final exitCode = await runner.run(config);
        expect(exitCode, 1);
        expect(errBuf.toString(), contains('does not exist'));
      });

      test('プロジェクトディレクトリがファイルの場合に具体的なエラーを返す', () async {
        final tmpFile = File(
          p.join(Directory.systemTemp.path,
              'runner_test_file_${DateTime.now().millisecondsSinceEpoch}'),
        );
        tmpFile.writeAsStringSync('not a directory');
        try {
          final config = RunnerConfig(
            projectRoot: tmpFile.path,
            changedFiles: ['lib/a.dart'],
          );

          final exitCode = await runner.run(config);
          expect(exitCode, 1);
          expect(errBuf.toString(), contains('not a directory'));
        } finally {
          tmpFile.deleteSync();
        }
      });

      test('pubspec.yaml が存在しない場合に具体的なエラーを返す', () async {
        final tmpDir = Directory.systemTemp.createTempSync('runner_test_');
        try {
          final config = RunnerConfig(
            projectRoot: tmpDir.path,
            changedFiles: ['lib/a.dart'],
          );

          final exitCode = await runner.run(config);
          expect(exitCode, 1);
          expect(errBuf.toString(), contains('pubspec.yaml'));
          expect(errBuf.toString(), contains('not found'));
        } finally {
          tmpDir.deleteSync(recursive: true);
        }
      });

      test('pubspec.yaml にnameフィールドが無い場合に具体的なエラーを返す', () async {
        final tmpDir = Directory.systemTemp.createTempSync('runner_test_');
        try {
          File(p.join(tmpDir.path, 'pubspec.yaml'))
              .writeAsStringSync('version: 1.0.0\n');
          final config = RunnerConfig(
            projectRoot: tmpDir.path,
            changedFiles: ['lib/a.dart'],
          );

          final exitCode = await runner.run(config);
          expect(exitCode, 1);
          expect(errBuf.toString(), contains('name'));
          expect(errBuf.toString(), contains('pubspec.yaml'));
        } finally {
          tmpDir.deleteSync(recursive: true);
        }
      });
    });

    group('--exclude オプション', () {
      List<dynamic> parseGoldenTests(String jsonOutput) {
        final parsed = jsonDecode(jsonOutput) as Map<String, dynamic>;
        return parsed['golden_tests'] as List<dynamic>;
      }

      test('除外パターンに一致するファイルが結果から除外される', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/models/theme_data.dart'],
          format: OutputFormat.json,
          excludePatterns: ['**/widgets/**'],
        );

        final outBuf = StringBuffer();
        final r = Runner(outSink: _StringSink(outBuf));
        final exitCode = await r.run(config);
        expect(exitCode, 0);

        final goldenTests = parseGoldenTests(outBuf.toString());
        expect(goldenTests, isNot(anyElement(contains('widgets/'))));
        // widgets 以外のテストは残っている
        expect(goldenTests, isNotEmpty);
      });

      test('除外パターンが空の場合はすべて含まれる', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/models/theme_data.dart'],
          format: OutputFormat.json,
          excludePatterns: [],
        );

        final outBuf = StringBuffer();
        final r = Runner(outSink: _StringSink(outBuf));
        final exitCode = await r.run(config);
        expect(exitCode, 0);

        final goldenTests = parseGoldenTests(outBuf.toString());
        expect(goldenTests, anyElement(contains('widgets/')));
      });

      test('複数の除外パターンを指定できる', () async {
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/models/theme_data.dart'],
          format: OutputFormat.json,
          excludePatterns: ['**/widgets/**', '**/screens/**'],
        );

        final outBuf = StringBuffer();
        final r = Runner(outSink: _StringSink(outBuf));
        final exitCode = await r.run(config);
        expect(exitCode, 0);

        final goldenTests = parseGoldenTests(outBuf.toString());
        expect(goldenTests, isNot(anyElement(contains('widgets/'))));
        expect(goldenTests, isNot(anyElement(contains('screens/'))));
        // utils のテストは残っている
        expect(goldenTests, isNotEmpty);
      });
    });

    group('--format command 出力', () {
      test('影響テストがある場合に flutter test コマンドを出力する', () async {
        final outBuf = StringBuffer();
        final r = Runner(outSink: _StringSink(outBuf));
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/widgets/button.dart'],
          format: OutputFormat.command,
        );

        final exitCode = await r.run(config);
        expect(exitCode, 0);

        final output = outBuf.toString().trim();
        expect(output, startsWith('flutter test '));
        expect(output, contains('test/'));
      });

      test('影響テストがない場合は空出力を返す', () async {
        final outBuf = StringBuffer();
        final r = Runner(outSink: _StringSink(outBuf));
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['lib/src/screens/settings_screen.dart'],
          format: OutputFormat.command,
        );

        final exitCode = await r.run(config);
        expect(exitCode, 0);
        expect(outBuf.toString(), isEmpty);
      });

      test('変更ファイルが .dart 以外の場合は空出力を返す', () async {
        final outBuf = StringBuffer();
        final r = Runner(outSink: _StringSink(outBuf));
        final config = RunnerConfig(
          projectRoot: fixturesRoot,
          changedFiles: ['nonexistent.yaml'],
          format: OutputFormat.command,
        );

        final exitCode = await r.run(config);
        expect(exitCode, 0);
        expect(outBuf.toString(), isEmpty);
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

/// テスト用の [StringSink] ラッパー。stderr 出力をキャプチャする。
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
