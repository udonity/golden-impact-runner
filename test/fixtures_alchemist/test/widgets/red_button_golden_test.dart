import 'package:alchemist_example/widgets/widgets.dart';

void main() {
  // alchemist スタイルの golden test
  goldenTest(
    'renders correctly',
    fileName: 'red_button',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'enabled',
          child: RedButton(onPressed: () {}),
        ),
      ],
    ),
  );
}

// テスト用スタブ（alchemist パッケージの型を模倣）
void goldenTest(String name, {String? fileName, Function? builder}) {}
class GoldenTestGroup { GoldenTestGroup({List? children}); }
class GoldenTestScenario { GoldenTestScenario({String? name, dynamic child}); }
