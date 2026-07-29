import 'package:flutter/material.dart';
import 'package:happy_news/core/themes/app_durations.dart';
import 'package:happy_news/core/themes/app_spacing.dart';

class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({
    required this.onTap,
    this.visible = true,
    super.key,
  });

  final VoidCallback onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        child: Semantics(
          label: '맨 위로',
          button: true,
          child: Tooltip(
            message: '맨 위로',
            child: Material(
              color: colors.secondaryContainer,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: AppSpacing.p40,
                  height: AppSpacing.p40,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
