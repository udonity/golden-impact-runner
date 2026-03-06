// test/fixtures_widget/lib/widgets/dialog.dart
import 'package:flutter/material.dart';
import 'card.dart';

/// AppCard を使用する StatefulWidget
class AppDialog extends StatefulWidget {
  const AppDialog({super.key});

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  @override
  Widget build(BuildContext context) {
    return const Dialog(child: AppCard(title: 'Dialog'));
  }
}
