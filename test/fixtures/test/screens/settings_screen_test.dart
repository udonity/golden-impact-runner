import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/src/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen test', (tester) async {
    // 通常のテスト、golden test ではない
    await tester.pumpWidget(const SettingsScreen());
    expect(find.text('Settings'), findsOneWidget);
  });
}
