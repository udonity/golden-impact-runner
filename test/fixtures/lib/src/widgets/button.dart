import 'package:flutter/material.dart';
import '../models/theme_data.dart';

class CommonButton extends StatelessWidget {
  const CommonButton({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      child: Text(label),
    );
  }
}
