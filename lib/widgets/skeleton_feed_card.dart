import 'package:flutter/material.dart';
import 'package:keek_news/widgets/skeleton_box.dart';

class SkeletonFeedCard extends StatelessWidget {
  const SkeletonFeedCard({super.key, this.screenHeight});
  final double? screenHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: isDark ? 0 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          SkeletonBox(
            width: double.infinity,
            height: _feedMediaHeight(
              screenHeight ?? MediaQuery.sizeOf(context).height,
            ),
            borderRadius: BorderRadius.zero,
          ),
          _actionRow(),
          _caption(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SkeletonBox(
            width: 32,
            height: 32,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow() {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          SkeletonBox(width: 24, height: 24),
          SizedBox(width: 8),
          SkeletonBox(width: 40, height: 12),
          SizedBox(width: 16),
          SkeletonBox(width: 24, height: 24),
          Spacer(),
          SkeletonBox(width: 60, height: 12),
        ],
      ),
    );
  }

  Widget _caption() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: double.infinity, height: 14),
          SizedBox(height: 8),
          SkeletonBox(width: 200, height: 12),
        ],
      ),
    );
  }
}

double _feedMediaHeight(double screenHeight) {
  const ratio = 0.66;
  const min = 420.0;
  const max = 600.0;
  final h = screenHeight * ratio;
  if (h < min) return min;
  if (h > max) return max;
  return h;
}
