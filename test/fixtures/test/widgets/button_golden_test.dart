import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/widgets/button.dart';

void main() {
  testWidgets('CommonButton golden', (tester) async {
    await tester.pumpWidget(const CommonButton(label: 'Test'));
    await expectLater(
      find.byType(CommonButton),
      matchesGoldenFile('goldens/button.png'),
    );
  });
}
