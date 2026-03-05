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

      group('一時gitリポジトリを使ったテスト', () {
        late Directory tempDir;
        late String repoPath;

        setUp(() async {
          tempDir = await Directory.systemTemp.createTemp('diff_provider_test_');
          repoPath = tempDir.path;

          // gitリポジトリを初期化
          await Process.run('git', ['init'], workingDirectory: repoPath);
          await Process.run(
            'git',
            ['config', 'user.email', 'test@test.com'],
            workingDirectory: repoPath,
          );
          await Process.run(
            'git',
            ['config', 'user.name', 'Test'],
            workingDirectory: repoPath,
          );

          // 初期コミット
          final initFile = File(p.join(repoPath, 'init.dart'));
          await initFile.writeAsString('// init');
          await Process.run('git', ['add', '.'], workingDirectory: repoPath);
          await Process.run(
            'git',
            ['commit', '-m', 'init'],
            workingDirectory: repoPath,
          );

          // mainブランチを作成（originなしでローカルブランチを使用）
          await Process.run(
            'git',
            ['branch', '-M', 'main'],
            workingDirectory: repoPath,
          );
        });

        tearDown(() async {
          await tempDir.delete(recursive: true);
        });

        test('変更された.dartファイルを正しく検出する', () async {
          // featureブランチを作成して変更をコミット
          await Process.run(
            'git',
            ['checkout', '-b', 'feature'],
            workingDirectory: repoPath,
          );

          final dartFile = File(p.join(repoPath, 'lib', 'a.dart'));
          await dartFile.parent.create(recursive: true);
          await dartFile.writeAsString('class A {}');

          await Process.run('git', ['add', '.'], workingDirectory: repoPath);
          await Process.run(
            'git',
            ['commit', '-m', 'add a.dart'],
            workingDirectory: repoPath,
          );

          final provider = DiffProvider(repoPath);
          final result = await provider.getChangedDartFiles(
            baseBranch: 'main',
            head: 'HEAD',
          );

          expect(result, hasLength(1));
          expect(result.first, endsWith('lib/a.dart'));
        });

        test('.dart以外のファイルは除外される', () async {
          await Process.run(
            'git',
            ['checkout', '-b', 'feature-non-dart'],
            workingDirectory: repoPath,
          );

          // .dartと非.dartファイルを両方追加
          final dartFile = File(p.join(repoPath, 'lib', 'b.dart'));
          await dartFile.parent.create(recursive: true);
          await dartFile.writeAsString('class B {}');

          final yamlFile = File(p.join(repoPath, 'pubspec.yaml'));
          await yamlFile.writeAsString('name: test');

          final mdFile = File(p.join(repoPath, 'README.md'));
          await mdFile.writeAsString('# Test');

          await Process.run('git', ['add', '.'], workingDirectory: repoPath);
          await Process.run(
            'git',
            ['commit', '-m', 'add mixed files'],
            workingDirectory: repoPath,
          );

          final provider = DiffProvider(repoPath);
          final result = await provider.getChangedDartFiles(
            baseBranch: 'main',
            head: 'HEAD',
          );

          expect(result, hasLength(1));
          expect(result.first, endsWith('lib/b.dart'));
        });

        test('変更がない場合は空のSetを返す', () async {
          final provider = DiffProvider(repoPath);
          final result = await provider.getChangedDartFiles(
            baseBranch: 'main',
            head: 'HEAD',
          );

          expect(result, isEmpty);
        });

        test('複数の.dartファイル変更を検出する', () async {
          await Process.run(
            'git',
            ['checkout', '-b', 'feature-multi'],
            workingDirectory: repoPath,
          );

          final libDir = Directory(p.join(repoPath, 'lib', 'src'));
          await libDir.create(recursive: true);

          for (final name in ['x.dart', 'y.dart', 'z.dart']) {
            final file = File(p.join(libDir.path, name));
            await file.writeAsString('// $name');
          }

          await Process.run('git', ['add', '.'], workingDirectory: repoPath);
          await Process.run(
            'git',
            ['commit', '-m', 'add multiple dart files'],
            workingDirectory: repoPath,
          );

          final provider = DiffProvider(repoPath);
          final result = await provider.getChangedDartFiles(
            baseBranch: 'main',
            head: 'HEAD',
          );

          expect(result, hasLength(3));
        });

        test('返されるパスがプロジェクトルートからの絶対パスである', () async {
          await Process.run(
            'git',
            ['checkout', '-b', 'feature-abs'],
            workingDirectory: repoPath,
          );

          final dartFile = File(p.join(repoPath, 'lib', 'abs.dart'));
          await dartFile.parent.create(recursive: true);
          await dartFile.writeAsString('// abs');

          await Process.run('git', ['add', '.'], workingDirectory: repoPath);
          await Process.run(
            'git',
            ['commit', '-m', 'add abs.dart'],
            workingDirectory: repoPath,
          );

          final provider = DiffProvider(repoPath);
          final result = await provider.getChangedDartFiles(
            baseBranch: 'main',
            head: 'HEAD',
          );

          expect(result, hasLength(1));
          final filePath = result.first;
          expect(p.isAbsolute(filePath), isTrue);
          expect(filePath, startsWith(repoPath));
        });

        test('存在しないブランチ指定でDiffExceptionを投げる', () async {
          final provider = DiffProvider(repoPath);
          await expectLater(
            provider.getChangedDartFiles(baseBranch: 'nonexistent-branch'),
            throwsA(isA<DiffException>()),
          );
        });
      });
    });

    group('GeneratedFileNormalizer', () {
      late Directory tempDir;

      setUp(() async {
        tempDir =
            await Directory.systemTemp.createTemp('generated_normalizer_test_');
      });

      tearDown(() async {
        await tempDir.delete(recursive: true);
      });

      test('.g.dart を元ファイルに正規化する', () {
        // 元ファイルを作成
        final baseFile = File(p.join(tempDir.path, 'model.dart'));
        baseFile.writeAsStringSync('class Model {}');

        final generatedPath = p.join(tempDir.path, 'model.g.dart');
        final result = GeneratedFileNormalizer.normalize({generatedPath});
        expect(result, {baseFile.path});
      });

      test('.freezed.dart を元ファイルに正規化する', () {
        final baseFile = File(p.join(tempDir.path, 'state.dart'));
        baseFile.writeAsStringSync('class State {}');

        final generatedPath = p.join(tempDir.path, 'state.freezed.dart');
        final result = GeneratedFileNormalizer.normalize({generatedPath});
        expect(result, {baseFile.path});
      });

      test('.gr.dart を元ファイルに正規化する', () {
        final baseFile = File(p.join(tempDir.path, 'router.dart'));
        baseFile.writeAsStringSync('class Router {}');

        final generatedPath = p.join(tempDir.path, 'router.gr.dart');
        final result = GeneratedFileNormalizer.normalize({generatedPath});
        expect(result, {baseFile.path});
      });

      test('元ファイルが存在しない場合は生成ファイル自体を返す', () {
        final generatedPath = p.join(tempDir.path, 'missing.g.dart');
        final result = GeneratedFileNormalizer.normalize({generatedPath});
        expect(result, {generatedPath});
      });

      test('通常の.dartファイルはそのまま返す', () {
        final filePath = p.join(tempDir.path, 'widget.dart');
        final result = GeneratedFileNormalizer.normalize({filePath});
        expect(result, {filePath});
      });

      test('生成ファイルと通常ファイルが混在する場合に正しく処理する', () {
        final baseFile = File(p.join(tempDir.path, 'model.dart'));
        baseFile.writeAsStringSync('class Model {}');

        final normalFile = p.join(tempDir.path, 'widget.dart');
        final generatedPath = p.join(tempDir.path, 'model.g.dart');

        final result =
            GeneratedFileNormalizer.normalize({normalFile, generatedPath});
        expect(result, {normalFile, baseFile.path});
      });

      test('複数の生成ファイルが同じ元ファイルを指す場合に重複を排除する', () {
        final baseFile = File(p.join(tempDir.path, 'model.dart'));
        baseFile.writeAsStringSync('class Model {}');

        final gPath = p.join(tempDir.path, 'model.g.dart');
        final freezedPath = p.join(tempDir.path, 'model.freezed.dart');

        final result =
            GeneratedFileNormalizer.normalize({gPath, freezedPath});
        expect(result, hasLength(1));
        expect(result, {baseFile.path});
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
