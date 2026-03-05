import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/widgets/user_card.dart';

void main() {
  testWidgets('UserCard golden test', (tester) async {
    await expectLater(
      find.byType(Container),
      matchesGoldenFile('goldens/user_card.png'),
    );
  });
}
