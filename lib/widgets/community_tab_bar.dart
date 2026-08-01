import 'package:flutter/material.dart';
import 'package:keek_news/const/app_sizes.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/community.dart';

class CommunityTabBar extends StatelessWidget {
  const CommunityTabBar({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: AppSizes.minTouchTarget,
      color: theme.colorScheme.surfaceContainer,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.p8),
        itemCount: communities.length,
        itemBuilder: (context, index) {
          final c = communities[index];
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.p16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: selected
                        ? Color(c.brandColorArgb)
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                c.shortName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? Color(c.brandColorArgb)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
