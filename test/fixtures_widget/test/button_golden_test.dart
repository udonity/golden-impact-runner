// test/fixtures_widget/test/button_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/button.dart';

void main() {
  testWidgets('AppButton golden', (tester) async {
    await tester.pumpWidget(const AppButton(label: 'Test'));
    await expectLater(find.byType(AppButton), matchesGoldenFile('goldens/button.png'));
  });
}
