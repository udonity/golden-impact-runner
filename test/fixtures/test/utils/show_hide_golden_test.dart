import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/utils/show_hide.dart';

void main() {
  testWidgets('ShowHide golden', (tester) async {
    await tester.pumpWidget(ShowHideExample.widget);
    await expectLater(
      find.byType(ShowHideExample),
      matchesGoldenFile('goldens/show_hide.png'),
    );
  });
}
