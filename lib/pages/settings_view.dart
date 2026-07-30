import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/pages/bookmarks_view.dart';
import 'package:keek_news/provider/cache_management_provider.dart';
import 'package:keek_news/provider/theme_provider.dart';
import 'package:keek_news/provider/update_provider.dart';
import 'package:keek_news/widgets/dark_mode_selector.dart';
import 'package:keek_news/widgets/settings_group.dart';
import 'package:keek_news/widgets/settings_tile.dart';
import 'package:keek_news/widgets/update_banner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/dev-hann/happy-news';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsView> {
  @override
  void initState() {
    super.initState();
    // Load the current image cache size so the tile shows it on first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(cacheManagementProvider.notifier).loadSize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final updateState = ref.watch(updateProvider);
    final cacheState = ref.watch(cacheManagementProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          children: [
            SettingsGroup(
              title: '저장함',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: '저장한 게시물',
                  onTap: () => _openBookmarks(context),
                ),
              ],
            ),
            SettingsGroup(
              title: '화면',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: '다크 모드',
                  trailing: DarkModeSelector(
                    currentMode: themeMode,
                    onChanged: (option) {
                      ref.read(themeProvider.notifier).setThemeMode(option);
                    },
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: '미디어 & 데이터',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: '이미지 캐시',
                  subtitle: '캐시 용량 ${_formatBytes(cacheState.sizeBytes)}',
                  onTap: () => _confirmClearCache(context),
                ),
              ],
            ),
            SettingsGroup(
              title: '정보',
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? 'v${snapshot.data!.version}'
                        : '...';
                    return SettingsTile(
                      leading: const Icon(Icons.info_outline),
                      title: '버전',
                      subtitle: version,
                    );
                  },
                ),
                UpdateBanner(
                  status: updateState.status,
                  newVersion: updateState.release?.version,
                  downloadProgress: updateState.downloadProgress,
                  hasApkDownloadUrl: updateState.release?.downloadUrl != null,
                  onCheck: () {
                    ref.read(updateProvider.notifier).checkForUpdate();
                  },
                  onUpdate: () {
                    final notifier = ref.read(updateProvider.notifier);
                    if (updateState.release?.downloadUrl != null) {
                      notifier.downloadUpdate();
                    } else {
                      final url = updateState.release?.htmlUrl;
                      if (url != null && url.isNotEmpty) {
                        _openUpdateUrl(url);
                      }
                    }
                  },
                  onCancelDownload: () {
                    ref.read(updateProvider.notifier).cancelDownload();
                  },
                  onInstall: () {
                    ref.read(updateProvider.notifier).launchInstaller();
                  },
                  onRetryDownload: () {
                    ref.read(updateProvider.notifier).downloadUpdate();
                  },
                  onOpenPermissionSettings: () {
                    ref
                        .read(updateProvider.notifier)
                        .openInstallPermissionSettings();
                  },
                ),
                SettingsTile(
                  leading: const Icon(Icons.description_outlined),
                  title: '오픈소스 라이선스',
                  onTap: () => _showLicenses(context),
                ),
                SettingsTile(
                  leading: const Icon(Icons.code_outlined),
                  title: '소스 코드',
                  subtitle: 'GitHub',
                  onTap: () => _launchUrl(_repoUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '계산 중…';
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openBookmarks(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BookmarksView()));
  }

  void _confirmClearCache(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이미지 캐시 삭제'),
        content: const Text('저장된 이미지 캐시를 모두 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(cacheManagementProvider.notifier).clear();
              _snackbar('이미지 캐시를 삭제했어요');
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _snackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: '킥뉴스',
      applicationLegalese: '© dev-hann',
    );
  }

  Future<void> _openUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    final launched =
        await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('업데이트 페이지를 열 수 없습니다.')));
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    final launched =
        await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
    }
  }
}
