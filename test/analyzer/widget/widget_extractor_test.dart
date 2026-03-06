// test/analyzer/widget/widget_extractor_test.dart
import 'package:golden_impact_runner/src/analyzer/widget/widget_extractor.dart';
import 'package:test/test.dart';

void main() {
  group('WidgetExtractor', () {
    late WidgetExtractor extractor;

    setUp(() {
      extractor = WidgetExtractor();
    });

    // === サポート対象 ===

    group('サポート対象', () {
      test('StatelessWidget を直接継承したクラスを検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  const MyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('button');
  }
}
''';
        final widgets = extractor.extractWidgets('/path/to/button.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'MyButton');
        expect(widgets[0].filePath, '/path/to/button.dart');
        expect(widgets[0].superclass, 'StatelessWidget');
      });

      test('StatefulWidget を直接継承したクラスを検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class MyDialog extends StatefulWidget {
  const MyDialog({super.key});

  @override
  State<MyDialog> createState() => _MyDialogState();
}

class _MyDialogState extends State<MyDialog> {
  @override
  Widget build(BuildContext context) {
    return const Text('dialog');
  }
}
''';
        final widgets = extractor.extractWidgets('/path/to/dialog.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'MyDialog');
        expect(widgets[0].superclass, 'StatefulWidget');
      });

      test('1ファイルに複数Widget定義がある場合すべて検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class WidgetA extends StatelessWidget {
  const WidgetA({super.key});
  @override
  Widget build(BuildContext context) => const Text('A');
}

class WidgetB extends StatelessWidget {
  const WidgetB({super.key});
  @override
  Widget build(BuildContext context) => const Text('B');
}
''';
        final widgets = extractor.extractWidgets('/path/to/multi.dart', source);

        expect(widgets, hasLength(2));
        expect(widgets.map((w) => w.name), containsAll(['WidgetA', 'WidgetB']));
      });

      test('ジェネリックWidget を検出する', () {
        const source = '''
import 'package:flutter/material.dart';

class GenericWidget<T> extends StatelessWidget {
  const GenericWidget({super.key});
  @override
  Widget build(BuildContext context) => const Text('generic');
}
''';
        final widgets = extractor.extractWidgets('/path/to/generic.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'GenericWidget');
        expect(widgets[0].superclass, 'StatelessWidget');
      });

      test('State<T> クラスを Widget定義として検出しない', () {
        const source = '''
import 'package:flutter/material.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) => const Text('state');
}
''';
        final widgets = extractor.extractWidgets('/path/to/stateful.dart', source);

        // MyWidget のみ検出、_MyWidgetState は検出しない
        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'MyWidget');
      });

      test('通常のクラス（Widget以外を継承）を検出しない', () {
        const source = '''
class UserModel {
  final String name;
  UserModel(this.name);
}

class ApiService extends BaseService {
  void fetch() {}
}
''';
        final widgets = extractor.extractWidgets('/path/to/model.dart', source);

        expect(widgets, isEmpty);
      });

      test('mixin を検出しない', () {
        const source = '''
mixin AnimationMixin on StatelessWidget {
  void animate() {}
}
''';
        final widgets = extractor.extractWidgets('/path/to/mixin.dart', source);

        expect(widgets, isEmpty);
      });

      test('extension を検出しない', () {
        const source = '''
extension WidgetExtension on Widget {
  Widget padded() => this;
}
''';
        final widgets = extractor.extractWidgets('/path/to/ext.dart', source);

        expect(widgets, isEmpty);
      });

      test('コメント内のクラス定義を検出しない', () {
        const source = '''
// class FakeWidget extends StatelessWidget {}

/*
class CommentedOut extends StatefulWidget {
  @override
  State<CommentedOut> createState() => _CommentedOutState();
}
*/
''';
        final widgets = extractor.extractWidgets('/path/to/commented.dart', source);

        expect(widgets, isEmpty);
      });
    });

    // === サポート外（フォールバック動作を検証）===

    group('サポート外', () {
      test('abstract Widget は検出する（定義自体はWidget）', () {
        const source = '''
import 'package:flutter/material.dart';

abstract class BaseWidget extends StatelessWidget {
  const BaseWidget({super.key});
}
''';
        final widgets = extractor.extractWidgets('/path/to/base.dart', source);

        expect(widgets, hasLength(1));
        expect(widgets[0].name, 'BaseWidget');
        expect(widgets[0].superclass, 'StatelessWidget');
      });

      test('中間基底クラス経由は Widget として検出しない', () {
        const source = '''
import 'base_widget.dart';

class DerivedWidget extends BaseWidget {
  const DerivedWidget({super.key});

  @override
  Widget build(BuildContext context) => const Text('derived');
}
''';
        final widgets = extractor.extractWidgets('/path/to/derived.dart', source);

        // BaseWidget は既知の StatelessWidget/StatefulWidget ではないため検出しない
        expect(widgets, isEmpty);
      });
    });

    // === extractAllWidgets ===

    group('extractAllWidgets', () {
      test('フィクスチャプロジェクト全体からWidget定義を収集する', () {
        final fixturesRoot = 'test/fixtures_widget';
        final result = extractor.extractAllWidgets(fixturesRoot);

        // button.dart: AppButton
        // card.dart: AppCard
        // dialog.dart: AppDialog
        // multi_widget.dart: WidgetA, WidgetB
        // base_widget.dart: BaseWidget (abstract)
        // derived_widget.dart: DerivedWidget は検出されない（中間基底）
        // utils.dart, indirect_usage.dart, models/user.dart: Widget なし
        final allWidgets = result.values.expand((list) => list).toList();
        final names = allWidgets.map((w) => w.name).toSet();

        expect(names, containsAll([
          'AppButton', 'AppCard', 'AppDialog',
          'WidgetA', 'WidgetB', 'BaseWidget',
        ]));
        expect(names, isNot(contains('DerivedWidget')));
        expect(names, isNot(contains('WidgetUtils')));
        expect(names, isNot(contains('User')));
      });
    });
  });
}
