import 'dart:io';

import 'package:golden_impact_runner/src/git/diff_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DiffProvider', () {
    group('resolveExplicitFiles', () {
      late DiffProvider provider;
      const projectRoot = '/project';

      setUp(() {
        provider = DiffProvider(projectRoot);
      });

      test('相対パスをプロジェクトルートからの絶対パスに変換する', () {
        final result = provider.resolveExplicitFiles(['lib/src/a.dart']);
        expect(result, {p.normalize('/project/lib/src/a.dart')});
      });

      test('絶対パスはそのまま保持する', () {
        final result = provider.resolveExplicitFiles(['/other/path/a.dart']);
        expect(result, {'/other/path/a.dart'});
      });

      test('.dart以外のファイルを除外する', () {
        final result = provider.resolveExplicitFiles([
          'lib/a.dart',
          'lib/b.yaml',
          'lib/c.txt',
        ]);
        expect(result, hasLength(1));
        expect(
          result.first,
          p.normalize('/project/lib/a.dart'),
        );
      });

      test('空のリストで空のSetを返す', () {
        final result = provider.resolveExplicitFiles([]);
        expect(result, isEmpty);
      });

      test('複数のdartファイルを正しく解決する', () {
        final result = provider.resolveExplicitFiles([
          'lib/a.dart',
          'lib/b.dart',
          'test/c_test.dart',
        ]);
        expect(result, hasLength(3));
      });

      test('重複するファイルはSetとして1つにまとめられる', () {
        final result = provider.resolveExplicitFiles([
          'lib/a.dart',
          'lib/a.dart',
        ]);
        expect(result, hasLength(1));
      });
    });

    group('getChangedDartFiles', () {
      test('存在しないディレクトリでProcessExceptionを投げる', () async {
        final provider = DiffProvider('/nonexistent/path/that/does/not/exist');
        await expectLater(
          provider.getChangedDartFiles(),
          throwsA(isA<ProcessException>()),
        );
      });
    });

    group('DiffException', () {
      test('toStringがメッセージを含む', () {
        final e = DiffException('test error');
        expect(e.toString(), contains('test error'));
        expect(e.toString(), contains('DiffException'));
      });

      test('messageフィールドにアクセスできる', () {
        final e = DiffException('some message');
        expect(e.message, 'some message');
      });
    });
  });
}
