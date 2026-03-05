import 'package:golden_impact_runner/src/analyzer/dependency_graph.dart';
import 'package:golden_impact_runner/src/analyzer/golden_test_detector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('End-to-end integration', () {
    late String fixturesRoot;

    setUp(() {
      fixturesRoot = p.normalize(p.join(p.current, 'test', 'fixtures'));
    });

    test('changing theme_data.dart impacts button golden test via transitive dep', () {
      // Simulate: theme_data.dart was changed
      final changedFile = p.normalize(
        p.join(fixturesRoot, 'lib', 'src', 'models', 'theme_data.dart'),
      );

      // Build graph
      final graph = DependencyGraph.build(
        projectRoot: fixturesRoot,
        packageName: 'test_app',
      );

      // Find impacted files
      final impacted = graph.findImpactedFiles({changedFile});

      // Filter to golden tests
      final detector = GoldenTestDetector(fixturesRoot);
      final goldenTests = detector.filterGoldenTests(impacted);

      final relative = goldenTests.map(
        (f) => p.relative(f, from: fixturesRoot),
      ).toSet();

      // theme_data → button → home_screen → home_screen_golden_test
      // theme_data → button → button_golden_test
      expect(relative, contains(
        p.join('test', 'widgets', 'button_golden_test.dart'),
      ));
      expect(relative, contains(
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
      ));

      // settings_screen_test is NOT a golden test, should not be included
      expect(relative, isNot(contains(
        p.join('test', 'screens', 'settings_screen_test.dart'),
      )));
    });

    test('changing settings_screen.dart does not impact button golden test', () {
      final changedFile = p.normalize(
        p.join(
          fixturesRoot,
          'lib',
          'src',
          'screens',
          'settings_screen.dart',
        ),
      );

      final graph = DependencyGraph.build(
        projectRoot: fixturesRoot,
        packageName: 'test_app',
      );

      final impacted = graph.findImpactedFiles({changedFile});
      final detector = GoldenTestDetector(fixturesRoot);
      final goldenTests = detector.filterGoldenTests(impacted);

      // settings_screen has no golden tests associated with it
      expect(goldenTests, isEmpty);
    });

    test('changing button.dart impacts both button and home_screen golden tests', () {
      final changedFile = p.normalize(
        p.join(fixturesRoot, 'lib', 'src', 'widgets', 'button.dart'),
      );

      final graph = DependencyGraph.build(
        projectRoot: fixturesRoot,
        packageName: 'test_app',
      );

      final impacted = graph.findImpactedFiles({changedFile});
      final detector = GoldenTestDetector(fixturesRoot);
      final goldenTests = detector.filterGoldenTests(impacted);

      final relative = goldenTests.map(
        (f) => p.relative(f, from: fixturesRoot),
      ).toSet();

      expect(relative, contains(
        p.join('test', 'widgets', 'button_golden_test.dart'),
      ));
      expect(relative, contains(
        p.join('test', 'screens', 'home_screen_golden_test.dart'),
      ));
    });
  });
}
