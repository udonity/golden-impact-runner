import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../analyzer/dependency_graph.dart';
import '../analyzer/golden_test_detector.dart';
import '../git/diff_provider.dart';

enum OutputFormat { text, json, command }

class RunnerConfig {
  const RunnerConfig({
    required this.projectRoot,
    this.baseBranch = 'origin/main',
    this.head = 'HEAD',
    this.changedFiles = const [],
    this.excludePatterns = const [],
    this.format = OutputFormat.text,
    this.verbose = false,
  });

  final String projectRoot;
  final String baseBranch;
  final String head;
  final List<String> changedFiles;

  /// 除外するファイルパターン（glob形式、例: `**/*.g.dart`）
  final List<String> excludePatterns;
  final OutputFormat format;
  final bool verbose;
}

/// メインオーケストレーター: diff・グラフ・検出を統合する。
class Runner {
  Runner({StringSink? errSink, StringSink? outSink})
      : _err = errSink ?? stderr,
        _out = outSink ?? stdout;

  final StringSink _err;
  final StringSink _out;

  Future<int> run(RunnerConfig config) async {
    final projectRoot = p.normalize(p.absolute(config.projectRoot));

    // 0. プロジェクトディレクトリの検証
    final projectDir = Directory(projectRoot);
    if (!projectDir.existsSync()) {
      // パスがファイルとして存在するか確認
      if (File(projectRoot).existsSync()) {
        _err.writeln('Error: $projectRoot is not a directory');
      } else {
        _err.writeln('Error: Project directory does not exist: $projectRoot');
      }
      return 1;
    }

    // 1. pubspec.yaml からパッケージ名を取得
    final packageName = _readPackageName(projectRoot);
    if (packageName == null) {
      final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
      if (!File(pubspecPath).existsSync()) {
        _err.writeln('Error: pubspec.yaml not found in $projectRoot');
      } else {
        _err.writeln(
          'Error: Could not read "name" field from pubspec.yaml in $projectRoot',
        );
      }
      return 1;
    }

    if (config.verbose) {
      _err.writeln('Project: $packageName ($projectRoot)');
    }

    // 2. 変更ファイルを取得
    final diffProvider = DiffProvider(projectRoot);
    Set<String> changedFiles;
    if (config.changedFiles.isNotEmpty) {
      changedFiles = diffProvider.resolveExplicitFiles(config.changedFiles);
    } else {
      try {
        changedFiles = await diffProvider.getChangedDartFiles(
          baseBranch: config.baseBranch,
          head: config.head,
        );
      } on DiffException catch (e) {
        _err.writeln('Error: $e');
        return 1;
      }
    }

    // 2.5. 生成ファイルを元ファイルに正規化
    changedFiles = GeneratedFileNormalizer.normalize(changedFiles);

    if (changedFiles.isEmpty) {
      if (config.verbose) {
        _err.writeln('No changed .dart files found.');
      }
      return 0;
    }

    if (config.verbose) {
      _err.writeln('Changed files (${changedFiles.length}):');
      for (final f in changedFiles) {
        _err.writeln('  ${p.relative(f, from: projectRoot)}');
      }
    }

    // 3. 依存グラフを構築
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

    // 4. BFS で影響ファイルをすべて検索
    final impactedFiles = graph.findImpactedFiles(changedFiles);

    if (config.verbose) {
      _err.writeln('Impacted files (${impactedFiles.length}):');
      for (final f in impactedFiles) {
        _err.writeln('  ${p.relative(f, from: projectRoot)}');
      }
    }

    // 5. golden test のみにフィルタ
    final detector = GoldenTestDetector(projectRoot);
    final goldenTests = detector.filterGoldenTests(impactedFiles);

    // 5.5. 除外パターンを適用
    final filteredTests = _applyExcludePatterns(
      goldenTests,
      config.excludePatterns,
      projectRoot,
    );

    // 6. 結果を出力
    if (config.format == OutputFormat.command) {
      if (filteredTests.isNotEmpty) {
        final sorted = filteredTests
            .map((f) => p.relative(f, from: projectRoot))
            .toList()
          ..sort();
        _out.writeln('flutter test ${sorted.join(' ')}');
      }
      // 影響テスト0件の場合は何も出力しない
      return 0;
    } else if (config.format == OutputFormat.json) {
      final output = {
        'changed_files': changedFiles
            .map((f) => p.relative(f, from: projectRoot))
            .toList()
          ..sort(),
        'impacted_files': impactedFiles
            .map((f) => p.relative(f, from: projectRoot))
            .toList()
          ..sort(),
        'golden_tests': filteredTests
            .map((f) => p.relative(f, from: projectRoot))
            .toList()
          ..sort(),
      };
      _out.writeln(const JsonEncoder.withIndent('  ').convert(output));
    } else {
      final sorted = filteredTests
          .map((f) => p.relative(f, from: projectRoot))
          .toList()
        ..sort();
      for (final test in sorted) {
        _out.writeln(test);
      }
    }

    return 0;
  }

  /// 除外パターンに一致するファイルを除去する。
  ///
  /// パターンは glob 風の簡易マッチ（`**` は任意のパスセグメント、`*` は任意の文字列）。
  Set<String> _applyExcludePatterns(
    Set<String> files,
    List<String> patterns,
    String projectRoot,
  ) {
    if (patterns.isEmpty) return files;

    final regexes = patterns.map(_globToRegExp).toList();
    return files.where((file) {
      final relative = p.relative(file, from: projectRoot);
      return !regexes.any((re) => re.hasMatch(relative));
    }).toSet();
  }

  /// 簡易 glob パターンを正規表現に変換する。
  RegExp _globToRegExp(String pattern) {
    final buf = StringBuffer('^');
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '*') {
        if (i + 1 < pattern.length && pattern[i + 1] == '*') {
          // ** は任意のパスセグメント（/ を含む）にマッチ
          buf.write('.*');
          i++; // 次の * をスキップ
          // 直後の / もスキップ
          if (i + 1 < pattern.length && pattern[i + 1] == '/') i++;
        } else {
          // * は / 以外の任意の文字列にマッチ
          buf.write('[^/]*');
        }
      } else if (c == '?') {
        buf.write('[^/]');
      } else if (_regExpMetaChars.contains(c)) {
        buf.write('\\$c');
      } else {
        buf.write(c);
      }
    }
    buf.write(r'$');
    return RegExp(buf.toString());
  }

  /// 正規表現でエスケープが必要なメタ文字。
  static const _regExpMetaChars = {
    '.',
    '+',
    '^',
    r'$',
    '|',
    '\\',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
  };

  String? _readPackageName(String projectRoot) {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return null;

    final content = pubspecFile.readAsStringSync();
    // yaml パッケージに依存せず、正規表現で pubspec.yaml から name を抽出
    final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(
      content,
    );
    return match?.group(1)?.replaceAll(RegExp(r"""^['"]|['"]$"""), '');
  }
}
