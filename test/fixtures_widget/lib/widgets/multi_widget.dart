// test/fixtures_widget/lib/widgets/multi_widget.dart
import 'package:flutter/material.dart';

/// 1ファイルに2つの Widget を定義（精度改善テスト用）
class WidgetA extends StatelessWidget {
  const WidgetA({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Widget A');
  }
}

class WidgetB extends StatelessWidget {
  const WidgetB({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Widget B');
  }
}
