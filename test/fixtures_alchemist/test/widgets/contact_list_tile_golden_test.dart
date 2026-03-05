import 'package:alchemist_example/widgets/widgets.dart';

void main() {
  goldenTest(
    'renders correctly',
    fileName: 'contact_list_tile',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'enabled',
          child: ContactListTile(name: 'Test', email: 'test@example.com'),
        ),
      ],
    ),
  );
}

void goldenTest(String name, {String? fileName, Function? builder}) {}
class GoldenTestGroup { GoldenTestGroup({List? children}); }
class GoldenTestScenario { GoldenTestScenario({String? name, dynamic child}); }
