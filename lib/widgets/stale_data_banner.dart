import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ShadAlert(
        icon: const Icon(LucideIcons.cloudOff, size: 16),
        description: Text(message),
      ),
    );
  }
}
