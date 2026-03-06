// test/fixtures_widget/test/card_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/card.dart';

void main() {
  testWidgets('AppCard golden', (tester) async {
    await tester.pumpWidget(const AppCard(title: 'Test'));
    await expectLater(find.byType(AppCard), matchesGoldenFile('goldens/card.png'));
  });
}
