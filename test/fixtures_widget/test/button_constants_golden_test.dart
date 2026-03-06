// test/fixtures_widget/test/button_constants_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/button_constants.dart';

void main() {
  testWidgets('button constants golden', (tester) async {
    // defaultLabel を使った表示テスト
    await tester.pumpWidget(Text(defaultLabel));
    await expectLater(find.text(defaultLabel), matchesGoldenFile('goldens/button_constants.png'));
  });
}
