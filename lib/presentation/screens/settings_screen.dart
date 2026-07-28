import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humoruniv/core/widgets/molecules/dark_mode_selector.dart';
import 'package:humoruniv/core/widgets/molecules/settings_group.dart';
import 'package:humoruniv/core/widgets/molecules/settings_tile.dart';
import 'package:humoruniv/core/widgets/molecules/update_banner.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/presentation/providers/cache_management_provider.dart';
import 'package:humoruniv/presentation/providers/community_settings_provider.dart';
import 'package:humoruniv/presentation/providers/theme_provider.dart';
import 'package:humoruniv/presentation/providers/update_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/dev-hann/humoruniv';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
    final commSettings = ref.watch(communitySettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          children: [
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
            SettingsGroup(
              title: '커뮤니티',
              children: [
                ...communities.map((c) {
                  final enabled = commSettings.isEnabled(c.id);
                  return SettingsTile(
                    leading: Icon(
                      Icons.circle,
                      color: Color(c.brandColorArgb),
                      size: 16,
                    ),
                    title: c.displayName,
                    trailing: Switch(
                      value: enabled,
                      onChanged: (_) => ref
                          .read(communitySettingsProvider.notifier)
                          .toggle(c.id),
                    ),
                  );
                }),
                SettingsTile(
                  leading: const Icon(Icons.balance_outlined),
                  title: '한 커뮤니티 최대 비율',
                  subtitle: '${(commSettings.maxRatio * 100).round()}%',
                  trailing: SizedBox(
                    width: 120,
                    child: Slider(
                      value: commSettings.maxRatio,
                      min: 0.25,
                      max: 0.6,
                      divisions: 7,
                      onChanged: (v) => ref
                          .read(communitySettingsProvider.notifier)
                          .setMaxRatio(v),
                    ),
                  ),
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
      applicationName: '웃긴대학',
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
