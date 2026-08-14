import 'package:flutter/material.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/widgets/inline_video_player.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CommentVideoViewerView extends StatelessWidget {
  const CommentVideoViewerView({required this.block, super.key});

  final VideoBlock block;

  @override
  Widget build(BuildContext context) {
    final aspect =
        (block.width != null && block.height != null && block.height! > 0)
        ? block.width! / block.height!
        : 16 / 9;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: InlineVideoPlayer(block: block, autoplay: true),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(LucideIcons.x),
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
