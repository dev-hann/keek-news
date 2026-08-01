import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Semantics(
          label: '맨 위로',
          button: true,
          child: Tooltip(
            message: '맨 위로',
            child: ShadIconButton(
              icon: const Icon(LucideIcons.arrowUp),
              onPressed: onTap,
              width: 40,
              height: 40,
            ),
          ),
        ),
      ),
    );
  }
}
