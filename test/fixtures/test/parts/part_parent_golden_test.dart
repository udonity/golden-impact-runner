import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/parts/part_parent.dart';

void main() {
  testWidgets('PartParent golden', (tester) async {
    await tester.pumpWidget(Text(PartParent().greet()));
    await expectLater(
      find.text('hello from parent'),
      matchesGoldenFile('goldens/part_parent.png'),
    );
  });
}
