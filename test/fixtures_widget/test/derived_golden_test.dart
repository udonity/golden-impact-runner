// test/fixtures_widget/test/derived_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_test_app/widgets/derived_widget.dart';

void main() {
  testWidgets('DerivedWidget golden', (tester) async {
    await tester.pumpWidget(const DerivedWidget());
    await expectLater(
      find.byType(DerivedWidget),
      matchesGoldenFile('goldens/derived.png'),
    );
  });
}
