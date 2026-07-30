import 'package:flutter/material.dart';

import 'package:keek_news/const/app_sizes.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Semantics(
      label: semanticsLabel,
      button: true,
      toggled: active,
      child: IconButton(
        icon: Icon(icon, size: AppSizes.iconMedium, color: color),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: AppSizes.minTouchTarget,
          minHeight: AppSizes.minTouchTarget,
        ),
        splashRadius: AppSizes.minTouchTarget / 2,
      ),
    );
  }
}
