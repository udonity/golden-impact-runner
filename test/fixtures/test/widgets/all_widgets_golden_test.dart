import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/widgets/widgets.dart';

void main() {
  testWidgets('AllWidgets golden', (tester) async {
    await tester.pumpWidget(const CommonButton(label: 'All'));
    await expectLater(
      find.byType(CommonButton),
      matchesGoldenFile('goldens/all_widgets.png'),
    );
  });
}
