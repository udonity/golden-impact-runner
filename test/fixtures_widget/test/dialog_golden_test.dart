// test/fixtures_widget/test/dialog_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/dialog.dart';

void main() {
  testWidgets('AppDialog golden', (tester) async {
    await tester.pumpWidget(const AppDialog());
    await expectLater(find.byType(AppDialog), matchesGoldenFile('goldens/dialog.png'));
  });
}
