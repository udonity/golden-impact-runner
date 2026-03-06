// test/fixtures_widget/lib/widgets/card.dart
import 'package:flutter/material.dart';
import 'button.dart';

/// AppButton を使用する StatelessWidget
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(title),
          const AppButton(label: 'Action'),
        ],
      ),
    );
  }
}
