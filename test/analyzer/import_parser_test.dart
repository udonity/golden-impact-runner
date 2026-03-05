import 'package:golden_impact_runner/src/analyzer/import_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ImportParser', () {
    late ImportParser parser;
    final projectRoot = '/project';

    setUp(() {
      parser = ImportParser(projectRoot, 'my_app');
    });

    group('extractDependencyUris', () {
      test('extracts simple imports', () {
        const content = '''
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/src/widgets/button.dart';
import '../models/user.dart';
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, [
          'dart:io',
          'package:flutter/material.dart',
          'package:my_app/src/widgets/button.dart',
          '../models/user.dart',
        ]);
      });

      test('extracts exports', () {
        const content = '''
export 'src/widgets/button.dart';
export 'package:my_app/src/models/user.dart';
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, [
          'src/widgets/button.dart',
          'package:my_app/src/models/user.dart',
        ]);
      });

      test('extracts part directives', () {
        const content = '''
part 'button.g.dart';
part 'button.freezed.dart';
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, ['button.g.dart', 'button.freezed.dart']);
      });

      test('ignores part of directives', () {
        const content = '''
part of 'button.dart';
part of 'package:my_app/src/widgets/button.dart';
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, isEmpty);
      });

      test('handles mixed directives', () {
        const content = '''
import 'dart:async';
import '../models/user.dart';
export 'src/utils.dart';
part 'home.g.dart';
part of 'parent.dart';
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, [
          'dart:async',
          '../models/user.dart',
          'src/utils.dart',
          'home.g.dart',
        ]);
      });

      test('handles single and double quotes', () {
        const content = '''
import "package:my_app/src/a.dart";
import 'package:my_app/src/b.dart';
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, [
          'package:my_app/src/a.dart',
          'package:my_app/src/b.dart',
        ]);
      });

      test('handles show/hide/as clauses', () {
        const content = '''
import 'package:my_app/src/a.dart' show Foo;
import 'package:my_app/src/b.dart' hide Bar;
import 'package:my_app/src/c.dart' as c;
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, hasLength(3));
      });

      test('returns empty for no directives', () {
        const content = '''
class Foo {
  void bar() {}
}
''';
        final uris = parser.extractDependencyUris(content);
        expect(uris, isEmpty);
      });

      group('conditional import', () {
        test('extracts both default and conditional URIs', () {
          const content = '''
import 'stub.dart' if (dart.library.io) 'real.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, containsAll(['stub.dart', 'real.dart']));
        });

        test('extracts multiple conditional clauses', () {
          const content = '''
import 'default.dart' if (dart.library.io) 'io.dart' if (dart.library.html) 'html.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(
              uris, containsAll(['default.dart', 'io.dart', 'html.dart']));
        });

        test('handles conditional import with package URIs', () {
          const content = '''
import 'package:my_app/src/stub.dart' if (dart.library.io) 'package:my_app/src/real.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, containsAll([
            'package:my_app/src/stub.dart',
            'package:my_app/src/real.dart',
          ]));
        });

        test('handles conditional export', () {
          const content = '''
export 'stub.dart' if (dart.library.io) 'real.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, containsAll(['stub.dart', 'real.dart']));
        });
      });

      group('deferred import', () {
        test('extracts deferred import URI', () {
          const content = '''
import 'package:my_app/src/heavy.dart' deferred as heavy;
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, contains('package:my_app/src/heavy.dart'));
        });

        test('extracts deferred import with relative path', () {
          const content = '''
import '../heavy/module.dart' deferred as module;
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, contains('../heavy/module.dart'));
        });
      });

      group('コメント内のimport文を無視', () {
        test('ignores single-line comment with import', () {
          const content = '''
// import 'package:my_app/src/old.dart';
import 'package:my_app/src/new.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, ['package:my_app/src/new.dart']);
        });

        test('ignores block comment with import', () {
          const content = '''
/* import 'package:my_app/src/old.dart'; */
import 'package:my_app/src/new.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, ['package:my_app/src/new.dart']);
        });

        test('ignores multiline block comment with imports', () {
          const content = '''
/*
import 'package:my_app/src/a.dart';
export 'package:my_app/src/b.dart';
part 'c.g.dart';
*/
import 'package:my_app/src/real.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, ['package:my_app/src/real.dart']);
        });

        test('ignores doc comment with import', () {
          const content = '''
/// import 'package:my_app/src/example.dart';
/// 使用例：import 'foo.dart';
import 'package:my_app/src/real.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, ['package:my_app/src/real.dart']);
        });

        test('handles nested block comments correctly', () {
          const content = '''
import 'package:my_app/src/before.dart';
/* コメント開始
import 'package:my_app/src/commented.dart';
コメント終了 */
import 'package:my_app/src/after.dart';
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, [
            'package:my_app/src/before.dart',
            'package:my_app/src/after.dart',
          ]);
        });

        test('handles inline comment after real import', () {
          const content = '''
import 'package:my_app/src/real.dart'; // import用
''';
          final uris = parser.extractDependencyUris(content);
          expect(uris, ['package:my_app/src/real.dart']);
        });
      });
    });

    group('resolveUri', () {
      test('returns null for dart: imports', () {
        expect(parser.resolveUri('dart:io', '/project/lib/a.dart'), isNull);
        expect(parser.resolveUri('dart:async', '/project/lib/a.dart'), isNull);
      });

      test('resolves own package imports', () {
        final result = parser.resolveUri(
          'package:my_app/src/widgets/button.dart',
          '/project/lib/src/screens/home.dart',
        );
        expect(
          result,
          p.normalize('/project/lib/src/widgets/button.dart'),
        );
      });

      test('returns null for external package imports', () {
        expect(
          parser.resolveUri(
            'package:flutter/material.dart',
            '/project/lib/a.dart',
          ),
          isNull,
        );
        expect(
          parser.resolveUri(
            'package:provider/provider.dart',
            '/project/lib/a.dart',
          ),
          isNull,
        );
      });

      test('resolves relative imports', () {
        final result = parser.resolveUri(
          '../models/user.dart',
          '/project/lib/src/screens/home.dart',
        );
        expect(
          result,
          p.normalize('/project/lib/src/models/user.dart'),
        );
      });

      test('resolves same-directory imports', () {
        final result = parser.resolveUri(
          'button.g.dart',
          '/project/lib/src/widgets/button.dart',
        );
        expect(
          result,
          p.normalize('/project/lib/src/widgets/button.g.dart'),
        );
      });
    });
  });
}
