import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    super.key,
    this.leading,
    this.trailing,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Renders the title and leading icon in [ColorScheme.error]. Use for
  /// destructive actions (clear cache, reset history, etc.). Color is never
  /// the sole signal — pair it with an error-flavored leading icon.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mTheme = Theme.of(context);
    final color = destructive
        ? mTheme.colorScheme.error
        : theme.colorScheme.foreground;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconTheme.merge(
                  data: IconThemeData(color: color),
                  child: leading!,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
