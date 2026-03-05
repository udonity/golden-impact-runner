import 'package:golden_impact_runner/src/cli/args_parser.dart';
import 'package:golden_impact_runner/src/cli/runner.dart';
import 'package:test/test.dart';

void main() {
  group('ArgsParser', () {
    group('デフォルト値', () {
      test('引数なしでデフォルト設定を返す', () {
        final config = ArgsParser.parse([]);
        expect(config, isNotNull);
        expect(config!.projectRoot, '.');
        expect(config.baseBranch, 'origin/main');
        expect(config.head, 'HEAD');
        expect(config.changedFiles, isEmpty);
        expect(config.format, OutputFormat.text);
        expect(config.verbose, isFalse);
      });
    });

    group('各オプションのパース', () {
      test('--base でベースブランチを指定できる', () {
        final config = ArgsParser.parse(['--base', 'develop']);
        expect(config!.baseBranch, 'develop');
      });

      test('--head でheadを指定できる', () {
        final config = ArgsParser.parse(['--head', 'abc123']);
        expect(config!.head, 'abc123');
      });

      test('--project でプロジェクトルートを指定できる', () {
        final config = ArgsParser.parse(['--project', '/tmp/my_app']);
        expect(config!.projectRoot, '/tmp/my_app');
      });

      test('--changed で変更ファイルを指定できる', () {
        final config = ArgsParser.parse(['--changed', 'lib/a.dart']);
        expect(config!.changedFiles, ['lib/a.dart']);
      });

      test('--changed を複数回指定できる', () {
        final config = ArgsParser.parse([
          '--changed', 'lib/a.dart',
          '--changed', 'lib/b.dart',
        ]);
        expect(config!.changedFiles, ['lib/a.dart', 'lib/b.dart']);
      });

      test('--format json でJSON出力を指定できる', () {
        final config = ArgsParser.parse(['--format', 'json']);
        expect(config!.format, OutputFormat.json);
      });

      test('--format text でテキスト出力を指定できる', () {
        final config = ArgsParser.parse(['--format', 'text']);
        expect(config!.format, OutputFormat.text);
      });

      test('--verbose で詳細出力を有効にできる', () {
        final config = ArgsParser.parse(['--verbose']);
        expect(config!.verbose, isTrue);
      });

      test('-v で詳細出力を有効にできる', () {
        final config = ArgsParser.parse(['-v']);
        expect(config!.verbose, isTrue);
      });
    });

    group('複合オプション', () {
      test('複数のオプションを同時に指定できる', () {
        final config = ArgsParser.parse([
          '--base', 'develop',
          '--head', 'feature-branch',
          '--project', '/tmp/app',
          '--changed', 'lib/x.dart',
          '--format', 'json',
          '--verbose',
        ]);
        expect(config!.baseBranch, 'develop');
        expect(config.head, 'feature-branch');
        expect(config.projectRoot, '/tmp/app');
        expect(config.changedFiles, ['lib/x.dart']);
        expect(config.format, OutputFormat.json);
        expect(config.verbose, isTrue);
      });
    });

    group('--help', () {
      test('--help でnullを返す', () {
        final config = ArgsParser.parse(['--help']);
        expect(config, isNull);
      });

      test('-h でnullを返す', () {
        final config = ArgsParser.parse(['-h']);
        expect(config, isNull);
      });
    });

    group('エラーケース', () {
      test('不明な引数でFormatExceptionを投げる', () {
        expect(
          () => ArgsParser.parse(['--unknown']),
          throwsA(isA<FormatException>()),
        );
      });

      test('--base に値がない場合FormatExceptionを投げる', () {
        expect(
          () => ArgsParser.parse(['--base']),
          throwsA(isA<FormatException>()),
        );
      });

      test('--head に値がない場合FormatExceptionを投げる', () {
        expect(
          () => ArgsParser.parse(['--head']),
          throwsA(isA<FormatException>()),
        );
      });

      test('--changed に値がない場合FormatExceptionを投げる', () {
        expect(
          () => ArgsParser.parse(['--changed']),
          throwsA(isA<FormatException>()),
        );
      });

      test('--project に値がない場合FormatExceptionを投げる', () {
        expect(
          () => ArgsParser.parse(['--project']),
          throwsA(isA<FormatException>()),
        );
      });

      test('--format に値がない場合FormatExceptionを投げる', () {
        expect(
          () => ArgsParser.parse(['--format']),
          throwsA(isA<FormatException>()),
        );
      });

      test('--format に不正な値を渡すとFormatExceptionを投げる', () {
        expect(
          () => ArgsParser.parse(['--format', 'xml']),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
