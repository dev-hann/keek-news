import 'package:flutter/material.dart';
import 'package:keek_news/model/community.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CommunityTabBar extends StatelessWidget {
  const CommunityTabBar({
    required this.communities,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });
  final List<Community> communities;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (var i = 0; i < communities.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _chip(context, theme, i)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, ShadThemeData theme, int i) {
    final c = communities[i];
    final selected = i == selectedIndex;
    final brandColor = Color(c.brandColorArgb);

    return GestureDetector(
      onTap: () => onChanged(i),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: c.displayName,
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? brandColor.withValues(alpha: 0.15)
                : theme.colorScheme.muted,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(
              color: selected ? brandColor : Colors.transparent,
            ),
          ),
          child: Text(
            c.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? brandColor : theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
