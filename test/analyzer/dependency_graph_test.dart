import 'package:golden_impact_runner/src/analyzer/dependency_graph.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DependencyGraph', () {
    late String fixturesRoot;
    late DependencyGraph graph;

    setUp(() {
      fixturesRoot = p.normalize(p.join(p.current, 'test', 'fixtures'));
      graph = DependencyGraph.build(
        projectRoot: fixturesRoot,
        packageName: 'test_app',
      );
    });

    test('discovers all dart files', () {
      // lib: button.dart, theme_data.dart, home_screen.dart, settings_screen.dart
      // test: button_golden_test.dart, home_screen_golden_test.dart, settings_screen_test.dart
      expect(graph.allFiles.length, 7);
    });

    test('builds forward dependencies correctly', () {
      final buttonPath = p.normalize(
        p.join(fixturesRoot, 'lib', 'src', 'widgets', 'button.dart'),
      );
      final deps = graph.dependsOn[buttonPath];
      expect(deps, isNotNull);

      // button.dart imports ../models/theme_data.dart (flutter import is ignored)
      final themeDataPath = p.normalize(
        p.join(fixturesRoot, 'lib', 'src', 'models', 'theme_data.dart'),
      );
      expect(deps, contains(themeDataPath));
    });

    test('builds reverse dependencies correctly', () {
      final buttonPath = p.normalize(
        p.join(fixturesRoot, 'lib', 'src', 'widgets', 'button.dart'),
      );

      final reverseDeps = graph.dependedOnBy[buttonPath];
      expect(reverseDeps, isNotNull);

      // button.dart is depended on by home_screen.dart
      final homeScreenPath = p.normalize(
        p.join(fixturesRoot, 'lib', 'src', 'screens', 'home_screen.dart'),
      );
      expect(reverseDeps, contains(homeScreenPath));
    });

    group('findImpactedFiles', () {
      test('finds direct dependents', () {
        final themeDataPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'src', 'models', 'theme_data.dart'),
        );

        final impacted = graph.findImpactedFiles({themeDataPath});

        // theme_data.dart → button.dart → home_screen.dart
        final buttonPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'src', 'widgets', 'button.dart'),
        );
        expect(impacted, contains(buttonPath));
      });

      test('finds transitive dependents via BFS', () {
        final themeDataPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'src', 'models', 'theme_data.dart'),
        );

        final impacted = graph.findImpactedFiles({themeDataPath});

        // theme_data.dart → button.dart → home_screen.dart
        final homeScreenPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'src', 'screens', 'home_screen.dart'),
        );
        expect(impacted, contains(homeScreenPath));
      });

      test('includes changed file itself', () {
        final buttonPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'src', 'widgets', 'button.dart'),
        );
        final impacted = graph.findImpactedFiles({buttonPath});
        expect(impacted, contains(buttonPath));
      });

      test('does not include unrelated files', () {
        final settingsPath = p.normalize(
          p.join(
            fixturesRoot,
            'lib',
            'src',
            'screens',
            'settings_screen.dart',
          ),
        );

        // Changing theme_data should not impact settings_screen
        // (settings_screen has no dependency on theme_data or button)
        final themeDataPath = p.normalize(
          p.join(fixturesRoot, 'lib', 'src', 'models', 'theme_data.dart'),
        );
        final impacted = graph.findImpactedFiles({themeDataPath});
        expect(impacted, isNot(contains(settingsPath)));
      });
    });
  });
}
