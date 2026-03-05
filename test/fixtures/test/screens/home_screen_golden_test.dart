import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen golden', (tester) async {
    await tester.pumpWidget(const HomeScreen());
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen.png'),
    );
  });
}
