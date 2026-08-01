import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.imageUrl, this.radius});
  final String? imageUrl;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? 32 / 2;
    return ShadAvatar(
      imageUrl,
      size: Size.fromRadius(r),
      placeholder: Icon(
        LucideIcons.user,
        size: r,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
