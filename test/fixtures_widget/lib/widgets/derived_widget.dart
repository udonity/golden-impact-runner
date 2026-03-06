// test/fixtures_widget/lib/widgets/derived_widget.dart
import 'package:flutter/material.dart';
import 'base_widget.dart';

/// 中間基底クラス経由の Widget（サポート外ケース）
/// MVP では BaseWidget が StatelessWidget であることを認識できないため、
/// DerivedWidget は Widget として検出されない。
/// ファイルレベルの依存追跡にフォールバックする。
class DerivedWidget extends BaseWidget {
  const DerivedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Derived');
  }
}
