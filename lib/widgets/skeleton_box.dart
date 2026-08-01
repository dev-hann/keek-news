import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.borderRadius});
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 44,
      decoration: BoxDecoration(
        color: ShadTheme.of(context).colorScheme.muted,
        borderRadius: borderRadius ?? BorderRadius.zero,
      ),
    );
  }
}
