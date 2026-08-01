import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      child: ShadIconButton.ghost(
        icon: Icon(icon, size: 16, color: color),
        onPressed: onTap,
        width: 44,
        height: 44,
      ),
    );
  }
}
