import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const Color _recTierLow = Color(0xFF9E9E9E);
const Color _recTierMid = Color(0xFFFF6D00);
const Color _recTierHigh = Color(0xFF43A047);
const Color _recTierHot = Color(0xFFE53935);

Color _recommendColor(int count) {
  if (count >= 100) return _recTierHot;
  if (count >= 50) return _recTierHigh;
  if (count >= 10) return _recTierMid;
  return _recTierLow;
}

FontWeight _recommendWeight(int count) {
  if (count >= 100) return FontWeight.w700;
  if (count >= 50) return FontWeight.w600;
  return FontWeight.w500;
}

class CountBadge extends StatelessWidget {
  const CountBadge({
    required this.count,
    required this.icon,
    super.key,
    this.color,
    this.fontWeight,
  });
  final int count;
  final IconData icon;
  final Color? color;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;
    return ShadBadge(
      backgroundColor: Colors.transparent,
      foregroundColor: effectiveColor,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontWeight: fontWeight)),
        ],
      ),
    );
  }
}

class RecommendBadge extends StatelessWidget {
  const RecommendBadge({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return CountBadge(
      count: count,
      icon: LucideIcons.thumbsUp,
      color: _recommendColor(count),
      fontWeight: _recommendWeight(count),
    );
  }
}

class CommentBadge extends StatelessWidget {
  const CommentBadge({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return CountBadge(
      count: count,
      icon: LucideIcons.messageCircle,
      color: ShadTheme.of(context).colorScheme.mutedForeground,
    );
  }
}

class ViewBadge extends StatelessWidget {
  const ViewBadge({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return CountBadge(
      count: count,
      icon: LucideIcons.eye,
      color: ShadTheme.of(context).colorScheme.mutedForeground,
    );
  }
}

class BestBadge extends StatelessWidget {
  const BestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadBadge(
      backgroundColor: _recommendColor(100),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: const Text('BEST', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
