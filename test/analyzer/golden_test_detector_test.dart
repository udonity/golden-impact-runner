import 'package:golden_impact_runner/src/analyzer/golden_test_detector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GoldenTestDetector', () {
    late String fixturesRoot;
    late GoldenTestDetector detector;

    setUp(() {
      fixturesRoot = p.normalize(
        p.join(p.current, 'test', 'fixtures'),
      );
      detector = GoldenTestDetector(fixturesRoot);
    });

    group('isGoldenTest', () {
      test('returns true for content with matchesGoldenFile', () {
        const content = '''
        await expectLater(
          find.byType(MyWidget),
          matchesGoldenFile('goldens/my_widget.png'),
        );
        ''';
        expect(detector.isGoldenTest(content), isTrue);
      });

      test('returns true for content with alchemist goldenTest', () {
        const content = '''
        goldenTest(
          'renders correctly',
          fileName: 'my_widget',
          builder: () => GoldenTestGroup(
            children: [
              GoldenTestScenario(
                name: 'default',
                child: MyWidget(),
              ),
            ],
          ),
        );
        ''';
        expect(detector.isGoldenTest(content), isTrue);
      });

      test('returns true for content with only GoldenTestGroup', () {
        const content = '''
        testWidgets('golden', (tester) async {
          await tester.pumpWidget(GoldenTestGroup(children: []));
        });
        ''';
        expect(detector.isGoldenTest(content), isTrue);
      });

      test('returns true for content with only GoldenTestScenario', () {
        const content = '''
        GoldenTestScenario(
          name: 'test',
          child: MyWidget(),
        );
        ''';
        expect(detector.isGoldenTest(content), isTrue);
      });

      test('returns false for regular test content', () {
        const content = '''
        expect(find.text('Hello'), findsOneWidget);
        ''';
        expect(detector.isGoldenTest(content), isFalse);
      });

      test('returns false for empty content', () {
        expect(detector.isGoldenTest(''), isFalse);
      });
    });

    group('findAllGoldenTests', () {
      test('finds golden test files in fixtures', () {
        final goldenTests = detector.findAllGoldenTests();
        final relative = goldenTests.map(
          (f) => p.relative(f, from: fixturesRoot),
        );

        expect(relative, containsAll([
          p.join('test', 'widgets', 'button_golden_test.dart'),
          p.join('test', 'screens', 'home_screen_golden_test.dart'),
        ]));

        // settings_screen_test.dart は golden test ではない
        expect(
          relative,
          isNot(contains(
            p.join('test', 'screens', 'settings_screen_test.dart'),
          )),
        );
      });
    });

    group('filterGoldenTests', () {
      test('filters only golden tests from impacted files', () {
        final buttonGolden = p.normalize(
          p.join(fixturesRoot, 'test', 'widgets', 'button_golden_test.dart'),
        );
        final settingsTest = p.normalize(
          p.join(fixturesRoot, 'test', 'screens', 'settings_screen_test.dart'),
        );
        final libFile = p.normalize(
          p.join(fixturesRoot, 'lib', 'src', 'widgets', 'button.dart'),
        );

        final result = detector.filterGoldenTests({
          buttonGolden,
          settingsTest,
          libFile,
        });

        expect(result, contains(buttonGolden));
        expect(result, isNot(contains(settingsTest)));
        expect(result, isNot(contains(libFile)));
      });
    });
  });
}
