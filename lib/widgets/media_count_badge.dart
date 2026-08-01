import 'package:flutter/material.dart';
import 'package:keek_news/const/app_colors.dart';
import 'package:keek_news/const/app_radius.dart';
import 'package:keek_news/const/app_spacing.dart';

class MediaCountBadge extends StatelessWidget {
  const MediaCountBadge({
    required this.text,
    this.style,
    this.borderRadius = AppRadius.borderRadiusLg,
    this.padding = AppSpacing.edgeH8V4,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.labelSmall;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.imageViewerOverlay,
        borderRadius: borderRadius,
      ),
      child: Text(
        text,
        style: base?.copyWith(
          color: AppColors.imageViewerForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
