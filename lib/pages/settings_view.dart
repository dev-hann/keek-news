import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/pages/bookmarks_view.dart';
import 'package:keek_news/provider/cache_management_provider.dart';
import 'package:keek_news/provider/update_provider.dart';
import 'package:keek_news/widgets/settings_group.dart';
import 'package:keek_news/widgets/settings_tile.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/dev-hann/happy-news';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsView> {
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(cacheManagementProvider.notifier).loadSize();
      ref.read(updateProvider.notifier).checkForUpdate();
      _loadVersion();
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _currentVersion = 'v${info.version}');
  }

  @override
  Widget build(BuildContext context) {
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
                SettingsTile(
                  leading: const Icon(Icons.info_outline),
                  title: '버전',
                  subtitle: _versionSubtitle(updateState),
                  trailing: _versionTrailing(context, updateState),
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

  String _versionLabel() => _currentVersion ?? '...';

  String _versionSubtitle(UpdateState state) {
    final base = _versionLabel();
    switch (state.status) {
      case UpdateCheckStatus.idle:
        return base;
      case UpdateCheckStatus.checking:
        return '$base · 확인 중…';
      case UpdateCheckStatus.upToDate:
        return '$base · 최신 버전';
      case UpdateCheckStatus.available:
        final newVersion = state.release?.version;
        return newVersion == null || newVersion.isEmpty
            ? base
            : '$base · v$newVersion 사용 가능';
      case UpdateCheckStatus.downloading:
        final percent = state.downloadProgress?.percent ?? 0;
        return '$base · 다운로드 $percent%';
      case UpdateCheckStatus.downloadError:
        return '$base · 다운로드 실패';
      case UpdateCheckStatus.readyToInstall:
        return '$base · 다운로드 완료';
      case UpdateCheckStatus.installPermissionRequired:
        return '$base · 설치 권한 필요';
      case UpdateCheckStatus.error:
        return '$base · 확인 실패';
    }
  }

  Widget? _versionTrailing(BuildContext context, UpdateState state) {
    switch (state.status) {
      case UpdateCheckStatus.checking:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UpdateCheckStatus.available:
        return FilledButton(onPressed: _onUpdateTap, child: const Text('업데이트'));
      case UpdateCheckStatus.downloading:
        return TextButton(
          onPressed: () => ref.read(updateProvider.notifier).cancelDownload(),
          child: const Text('취소'),
        );
      case UpdateCheckStatus.downloadError:
        return TextButton(
          onPressed: () => ref.read(updateProvider.notifier).downloadUpdate(),
          child: const Text('다시'),
        );
      case UpdateCheckStatus.readyToInstall:
        return FilledButton(
          onPressed: () => ref.read(updateProvider.notifier).launchInstaller(),
          child: const Text('설치'),
        );
      case UpdateCheckStatus.installPermissionRequired:
        return FilledButton(
          onPressed: () =>
              ref.read(updateProvider.notifier).openInstallPermissionSettings(),
          child: const Text('설정 열기'),
        );
      case UpdateCheckStatus.error:
        return TextButton(
          onPressed: () => ref.read(updateProvider.notifier).checkForUpdate(),
          child: const Text('다시'),
        );
      case UpdateCheckStatus.idle:
      case UpdateCheckStatus.upToDate:
        return null;
    }
  }

  void _onUpdateTap() {
    final notifier = ref.read(updateProvider.notifier);
    final release = ref.read(updateProvider).release;
    if (release?.downloadUrl != null) {
      notifier.downloadUpdate();
    } else {
      final url = release?.htmlUrl;
      if (url != null && url.isNotEmpty) {
        _openUpdateUrl(url);
      }
    }
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
