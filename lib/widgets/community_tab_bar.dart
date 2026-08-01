import 'package:flutter/material.dart';
import 'package:keek_news/model/community.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    return ShadTabs<int>(
      value: selectedIndex,
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onChanged: onChanged,
      tabs: [
        for (var i = 0; i < communities.length; i++)
          ShadTab(
            value: i,
            height: 44,
            backgroundColor: Colors.transparent,
            selectedBackgroundColor: Colors.transparent,
            hoverBackgroundColor: Colors.transparent,
            selectedHoverBackgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            selectedForegroundColor: Color(communities[i].brandColorArgb),
            textStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: Text(communities[i].shortName),
          ),
      ],
    );
  }
}
