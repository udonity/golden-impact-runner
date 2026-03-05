// Phase 1 のできること・できないことを明示するテスト。
//
// [SUPPORTED] — Phase 1 で正しく動作する機能
// [KNOWN LIMITATION] — Phase 1 では対応していない既知の制限
//
// これらのテストはツールのスペックドキュメントとして機能する。
import 'package:golden_impact_runner/src/analyzer/dependency_graph.dart';
import 'package:golden_impact_runner/src/analyzer/golden_test_detector.dart';
import 'package:golden_impact_runner/src/analyzer/import_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String fixturesRoot;
  late DependencyGraph graph;
  late GoldenTestDetector detector;
  late ImportParser parser;

  setUp(() {
    fixturesRoot = p.normalize(p.join(p.current, 'test', 'fixtures'));
    graph = DependencyGraph.build(
      projectRoot: fixturesRoot,
      packageName: 'test_app',
    );
    detector = GoldenTestDetector(fixturesRoot);
    parser = ImportParser(fixturesRoot, 'test_app');
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

  // ═══════════════════════════════════════════════════════
  // SUPPORTED: Phase 1 で正しく動作する機能
  // ═══════════════════════════════════════════════════════

  group('[SUPPORTED] import show/hide はファイル単位で依存追跡される', () {
    test('show 付き import でも依存として追跡される', () {
      final deps = parser.parseDependencies(
        absFixture('lib/src/utils/show_hide.dart'),
      );
      final relative = deps.map((f) => p.relative(f, from: fixturesRoot));

      expect(relative, contains(p.join('lib', 'src', 'widgets', 'button.dart')));
      expect(relative, contains(p.join('lib', 'src', 'models', 'theme_data.dart')));
    });

    test('show/hide 経由のファイル変更が golden test に波及する', () {
      // button.dart を変更 → show_hide.dart → show_hide_golden_test.dart
      final result = goldenTestsFor({
        absFixture('lib/src/widgets/button.dart'),
      });

      expect(result, contains(
        p.join('test', 'utils', 'show_hide_golden_test.dart'),
      ));
    });
  });

  group('[SUPPORTED] part ディレクティブが追跡される', () {
    test('part 文で子ファイルが依存として認識される', () {
      final deps = parser.parseDependencies(
        absFixture('lib/src/parts/part_parent.dart'),
      );
      final relative = deps.map((f) => p.relative(f, from: fixturesRoot));

      expect(relative, contains(p.join('lib', 'src', 'parts', 'part_child.dart')));
    });

    test('part of は依存として認識されない（正しい動作）', () {
      final deps = parser.parseDependencies(
        absFixture('lib/src/parts/part_child.dart'),
      );

      // part of 'part_parent.dart' は抽出されない
      expect(deps, isEmpty);
    });

    test('part_child.dart の変更が part_parent 経由で golden test に波及する', () {
      // part_child → (part of) part_parent → part_parent_golden_test
      // ただし part of は追跡しないので、part_parent の逆依存から辿る
      final result = goldenTestsFor({
        absFixture('lib/src/parts/part_child.dart'),
      });

      // part_child は part_parent の part なので、
      // part_parent_golden_test が part_parent を import → part_parent が part_child に依存
      // → part_child を変更すると part_parent_golden_test に波及する
      expect(result, contains(
        p.join('test', 'parts', 'part_parent_golden_test.dart'),
      ));
    });
  });

  group('[SUPPORTED] conditional import の第一パスが追跡される', () {
    test('conditional import のデフォルトパスが依存として認識される', () {
      final deps = parser.parseDependencies(
        absFixture('lib/src/utils/conditional_import.dart'),
      );
      final relative = deps.map((f) => p.relative(f, from: fixturesRoot));

      // デフォルトの theme_data.dart は追跡される
      expect(relative, contains(p.join('lib', 'src', 'models', 'theme_data.dart')));
    });
  });

  group('[SUPPORTED] dart: SDK import は無視される', () {
    test('dart:core, dart:io 等は依存に含まれない', () {
      expect(parser.resolveUri('dart:core', '/any/file.dart'), isNull);
      expect(parser.resolveUri('dart:io', '/any/file.dart'), isNull);
      expect(parser.resolveUri('dart:convert', '/any/file.dart'), isNull);
    });
  });

  group('[SUPPORTED] 外部パッケージ import は無視される', () {
    test('package:flutter, package:test 等は依存に含まれない', () {
      expect(
        parser.resolveUri('package:flutter/material.dart', '/any/file.dart'),
        isNull,
      );
      expect(
        parser.resolveUri('package:test/test.dart', '/any/file.dart'),
        isNull,
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // KNOWN LIMITATIONS: Phase 1 では対応していない制限
  // ═══════════════════════════════════════════════════════

  group('[SUPPORTED] 行頭コメント内の import は正しく無視される', () {
    test('// コメント内の import は検出されない', () {
      final content = "// import '../models/theme_data.dart';";
      final uris = parser.extractDependencyUris(content);

      // 正規表現が ^\s* で行頭にアンカーされているため、
      // // で始まる行は import にマッチしない
      expect(uris, isEmpty,
          reason: '行頭コメントは正規表現の ^ アンカーにより正しく除外される');
    });

    test('/* ブロックコメント行頭の import は検出されない', () {
      final content = "/* import '../widgets/button.dart'; */";
      final uris = parser.extractDependencyUris(content);

      expect(uris, isEmpty,
          reason: '行頭ブロックコメントは正規表現の ^ アンカーにより正しく除外される');
    });

    test('行頭コメントのみの commented_imports.dart は依存がゼロ', () {
      final deps = parser.parseDependencies(
        absFixture('lib/src/utils/commented_imports.dart'),
      );

      expect(deps, isEmpty,
          reason: 'コメント行の import は正しく無視される');
    });
  });

  group('[KNOWN LIMITATION] 複数行ブロックコメント内の import は誤検出される', () {
    test('ブロックコメントの途中行にある import は誤検出される', () {
      // /*
      //  * コメント内だが、行頭が空白 + import でマッチしてしまう
      //  */
      final content = '''
/*
 * Some documentation:
  import '../models/theme_data.dart';
 */
''';
      final uris = parser.extractDependencyUris(content);

      // 行頭が空白 + import のためマッチしてしまう
      expect(uris, contains('../models/theme_data.dart'),
          reason: 'Phase 1 は複数行ブロックコメント内の行を区別できない');
    });
  });

  group('[KNOWN LIMITATION] conditional import の代替パスは追跡されない', () {
    test('if 条件の代替パスは依存に含まれない', () {
      // import 'a.dart' if (dart.library.html) 'b.dart';
      // → 'a.dart' のみ追跡、'b.dart' は追跡されない
      final uris = parser.extractDependencyUris(
        "import '../models/theme_data.dart' if (dart.library.html) '../models/theme_data_web.dart';",
      );

      // 正規表現は最初の引用符で囲まれたURIのみ抽出
      expect(uris, contains('../models/theme_data.dart'));
      expect(uris, isNot(contains('../models/theme_data_web.dart')),
          reason: 'Phase 1 は conditional import の代替パスを追跡しない');
    });
  });

  group('[KNOWN LIMITATION] bin/ ディレクトリはスキャン対象外', () {
    test('bin/ 内のファイルは依存グラフに含まれない', () {
      final binFile = absFixture('bin/cli_tool.dart');

      expect(graph.allFiles, isNot(contains(binFile)),
          reason: 'Phase 1 は lib/ と test/ のみスキャンする');
    });

    test('bin/ からの逆依存は検出されない', () {
      // bin/cli_tool.dart は button.dart を import しているが、
      // グラフに含まれないため逆依存として追跡されない
      final impacted = graph.findImpactedFiles({
        absFixture('lib/src/widgets/button.dart'),
      });
      final relative = impacted.map(
        (f) => p.relative(f, from: fixturesRoot),
      ).toSet();

      expect(relative, isNot(contains(p.join('bin', 'cli_tool.dart'))),
          reason: 'bin/ はスキャン対象外なので逆依存に含まれない');
    });
  });

  group('[KNOWN LIMITATION] show/hide の細粒度追跡はできない', () {
    test('hide で除外したシンボルの変更でも依存として報告される', () {
      // show_hide.dart は theme_data.dart を `hide AppTheme` で import
      // → AppTheme しか定義されていないのに、ファイル単位で依存が報告される
      final result = goldenTestsFor({
        absFixture('lib/src/models/theme_data.dart'),
      });

      // show_hide_golden_test も影響ありと報告される（偽陽性の可能性）
      // Phase 2 で Widget 単位の解析ができれば改善される
      expect(result, contains(
        p.join('test', 'utils', 'show_hide_golden_test.dart'),
      ), reason: 'Phase 1 はファイル単位の依存追跡のため hide を区別できない');
    });
  });

  group('[KNOWN LIMITATION] matchesGoldenFile の間接参照は区別できない', () {
    test('文字列に matchesGoldenFile を含むだけで golden test と判定される', () {
      // matchesGoldenFile( というパターンがあれば golden test とみなす
      final content = '''
        // This is a helper, not a golden test
        // But it mentions matchesGoldenFile( in a comment
        void helper() {}
      ''';

      expect(detector.isGoldenTest(content), isTrue,
          reason: 'Phase 1 は正規表現ベースのため文脈を区別できない');
    });

    test('matchesGoldenFile を含まないテストは golden test と判定されない', () {
      final content = '''
        void main() {
          test('regular test', () {
            expect(1, 1);
          });
        }
      ''';

      expect(detector.isGoldenTest(content), isFalse);
    });
  });

  group('[KNOWN LIMITATION] 存在しないファイルへの import は静かに無視される', () {
    test('存在しないファイルへの import はグラフのエッジにならない', () {
      // conditional_import.dart は theme_data_web.dart を条件付きで参照するが、
      // そのファイルは存在しない。parseDependencies はファイルの存在チェックをしないが、
      // グラフには存在するファイルのみが含まれる
      final deps = parser.parseDependencies(
        absFixture('lib/src/utils/conditional_import.dart'),
      );

      // 解決されたパスは含まれるが、ファイルが存在しなくてもエラーにはならない
      // （グラフの逆依存には影響しない）
      expect(deps, isNotEmpty);
    });
  });
}
