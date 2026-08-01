import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mTheme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: mTheme.textTheme.titleSmall),
          ),
          Material(
            color: mTheme.colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Column(children: _buildChildrenWithDividers(theme)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers(ShadThemeData theme) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        result.add(ShadSeparator.horizontal(color: theme.colorScheme.border));
      }
      result.add(children[i]);
    }
    return result;
  }
}
