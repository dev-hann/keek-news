import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_sizes.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.imageUrl, this.radius});
  final String? imageUrl;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppSizes.avatarSmall / 2;
    return CircleAvatar(
      radius: r,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null
          ? Icon(
              Icons.person,
              size: r,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}
