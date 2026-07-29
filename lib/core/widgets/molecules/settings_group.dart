import 'package:flutter/material.dart';
import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_spacing.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.p4,
              bottom: AppSpacing.p8,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: AppRadius.borderRadiusLg,
            child: Column(children: _buildChildrenWithDividers()),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers() {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        result.add(const Divider(height: 1, indent: AppSpacing.p16));
      }
      result.add(children[i]);
    }
    return result;
  }
}
