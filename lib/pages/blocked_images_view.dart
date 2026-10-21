import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/provider/blocked_images_provider.dart';
import 'package:keek_news/widgets/blocked_image_tile.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Management screen for the image blocklist (설정 → 미디어 & 데이터 → 차단된
/// 이미지). Unblocking republishes through the repo's change stream, so the
/// image reappears in any open feed immediately.
class BlockedImagesView extends ConsumerWidget {
  const BlockedImagesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(blockedImagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('차단된 이미지')),
      body: SafeArea(
        child: images.isEmpty
            ? const EmptyStateView(
                title: '차단된 이미지가 없어요',
                subtitle: '이미지를 길게 눌러 차단할 수 있어요',
                icon: LucideIcons.imageOff,
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: images.length,
                itemBuilder: (context, index) => BlockedImageTile(
                  image: images[index],
                  onUnblock: () => _unblock(context, ref, images[index].url),
                ),
              ),
      ),
    );
  }

  Future<void> _unblock(BuildContext context, WidgetRef ref, String url) async {
    final result = await ref.read(blockedImagesProvider.notifier).unblock(url);
    if (!context.mounted) return;
    final message = result.fold((_) => '차단 해제에 실패했어요', (_) => '차단을 해제했어요');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
