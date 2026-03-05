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
