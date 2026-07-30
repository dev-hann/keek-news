import 'package:flutter/material.dart';

import 'package:keek_news/const/app_spacing.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.edgeH16V8,
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
