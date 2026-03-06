// test/fixtures_widget/test/multi_widget_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/multi_widget.dart';

void main() {
  // WidgetA のみの Golden Test（WidgetB のテストはない）
  testWidgets('WidgetA golden', (tester) async {
    await tester.pumpWidget(const WidgetA());
    await expectLater(find.byType(WidgetA), matchesGoldenFile('goldens/widget_a.png'));
  });
}
