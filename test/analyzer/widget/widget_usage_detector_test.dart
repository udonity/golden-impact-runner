// test/analyzer/widget/widget_usage_detector_test.dart
import 'package:golden_impact_runner/src/analyzer/widget/widget_usage_detector.dart';
import 'package:test/test.dart';

void main() {
  group('WidgetUsageDetector', () {
    late WidgetUsageDetector detector;

    setUp(() {
      // 既知の Widget 名を登録して初期化
      detector = WidgetUsageDetector(
        knownWidgets: {'MyWidget', 'AppButton', 'AppCard', 'OtherWidget'},
      );
    });

    // === サポート対象 ===

    group('サポート対象', () {
      test('コンストラクタ呼び出しを検出する', () {
        const source = '''
void main() {
  final w = MyWidget();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, hasLength(1));
        expect(usages[0].widgetName, 'MyWidget');
        expect(usages[0].filePath, '/path/to/file.dart');
      });

      test('const コンストラクタを検出する', () {
        const source = '''
void main() {
  const widget = const MyWidget();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, hasLength(1));
        expect(usages[0].widgetName, 'MyWidget');
      });

      test('named コンストラクタを検出する', () {
        const source = '''
void main() {
  final w = MyWidget.custom();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, hasLength(1));
        expect(usages[0].widgetName, 'MyWidget');
      });

      test('build() メソッド内でのネスト使用を検出する', () {
        const source = '''
class ParentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(label: 'OK'),
        AppCard(title: 'Card'),
      ],
    );
  }
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['AppButton', 'AppCard']));
      });

      test('変数への代入を検出する', () {
        const source = '''
void main() {
  final w = MyWidget();
  var x = AppButton(label: 'test');
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['MyWidget', 'AppButton']));
      });

      test('コレクション内の生成を検出する', () {
        const source = '''
void main() {
  final list = [MyWidget(), OtherWidget()];
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['MyWidget', 'OtherWidget']));
      });

      test('条件式内の両方を検出する', () {
        const source = '''
void main() {
  final w = true ? MyWidget() : OtherWidget();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);
        final names = usages.map((u) => u.widgetName).toSet();

        expect(names, containsAll(['MyWidget', 'OtherWidget']));
      });

      test('既知Widget名リストに含まれないクラスの生成を検出しない', () {
        const source = '''
void main() {
  final model = UserModel();
  final service = ApiService();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, isEmpty);
      });

      test('コメント内の記述を検出しない', () {
        const source = '''
// MyWidget() を使う
/* AppButton(label: 'test') */
void main() {}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, isEmpty);
      });
    });

    // === サポート外（フォールバック動作を検証）===

    group('サポート外', () {
      test('型アノテーションのみは使用として検出しない', () {
        const source = '''
class Holder {
  MyWidget? widget;
  List<AppButton> buttons = [];
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        expect(usages, isEmpty);
      });

      test('staticメソッド呼び出しは named コンストラクタと区別できず検出される（既知の制限）', () {
        const source = '''
void main() {
  final theme = MyWidget.of(context);
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        // 構文解析のみでは MyWidget.of() と MyWidget.named() を区別できない。
        // 安全サイド（漏れなし）で検出する。影響範囲が広がるだけで偽陰性は発生しない。
        expect(usages, hasLength(1));
        expect(usages[0].widgetName, 'MyWidget');
      });

      test('関数経由の間接生成は呼び出し側で検出されない', () {
        // buildDefaultButton() 内部で AppButton() を生成しているが、
        // この呼び出し側のファイルからは AppButton への依存は見えない
        const source = '''
import 'indirect_usage.dart';

void main() {
  final w = buildDefaultButton();
}
''';
        final usages = detector.detectUsages('/path/to/file.dart', source);

        // buildDefaultButton は Widget 名ではないので検出されない
        expect(usages, isEmpty);
      });
    });
  });
}
