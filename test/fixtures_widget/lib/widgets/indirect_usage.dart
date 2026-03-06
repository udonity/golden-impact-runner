// test/fixtures_widget/lib/widgets/indirect_usage.dart
import 'package:flutter/material.dart';
import 'button.dart';

/// 関数経由で Widget を返すヘルパー（サポート外ケース）
/// MVP では関数の戻り型を解析しないため、
/// この関数の呼び出し側では AppButton への依存が検出されない。
Widget buildDefaultButton() {
  return const AppButton(label: 'Default');
}
