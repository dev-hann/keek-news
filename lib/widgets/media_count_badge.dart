import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const Color _overlayBackground = Color(0x8A000000);
const Color _overlayForeground = Color(0xFFFFFFFF);

class MediaCountBadge extends StatelessWidget {
  const MediaCountBadge({
    required this.text,
    this.style,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    super.key,
  });

  final String text;
  final TextStyle? style;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.labelSmall;
    return ShadBadge(
      backgroundColor: _overlayBackground,
      foregroundColor: _overlayForeground,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      padding: padding,
      child: Text(
        text,
        style: base?.copyWith(
          color: _overlayForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
