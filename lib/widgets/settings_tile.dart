import 'package:flutter/material.dart';
import 'package:keek_news/const/app_spacing.dart';

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
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: leading == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: color),
              child: leading!,
            ),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p4,
      ),
      minVerticalPadding: AppSpacing.p8,
    );
  }
}
