// test/fixtures_widget/lib/widgets/button.dart
import 'package:flutter/material.dart';

/// シンプルな StatelessWidget
class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: () {}, child: Text(label));
  }
}
