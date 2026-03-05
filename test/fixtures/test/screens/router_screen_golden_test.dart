import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/screens/router_screen.dart';

void main() {
  testWidgets('RouterScreen golden test', (tester) async {
    await expectLater(
      find.byType(Container),
      matchesGoldenFile('goldens/router_screen.png'),
    );
  });
}
