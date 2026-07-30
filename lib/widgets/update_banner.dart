import 'package:flutter/material.dart';
import 'package:keek_news/const/app_radius.dart';
import 'package:keek_news/const/app_sizes.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/provider/update_provider.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    required this.status,
    super.key,
    this.newVersion,
    this.downloadProgress,
    this.hasApkDownloadUrl = true,
    this.onCheck,
    this.onUpdate,
    this.onCancelDownload,
    this.onInstall,
    this.onRetryDownload,
    this.onOpenPermissionSettings,
  });

  final UpdateCheckStatus status;
  final String? newVersion;
  final DownloadProgress? downloadProgress;
  final bool hasApkDownloadUrl;
  final VoidCallback? onCheck;
  final VoidCallback? onUpdate;
  final VoidCallback? onCancelDownload;
  final VoidCallback? onInstall;
  final VoidCallback? onRetryDownload;
  final VoidCallback? onOpenPermissionSettings;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      UpdateCheckStatus.idle => _IdleView(onCheck: onCheck),
      UpdateCheckStatus.checking => const _CheckingView(),
      UpdateCheckStatus.upToDate => const _UpToDateView(),
      UpdateCheckStatus.available => _AvailableView(
        newVersion: newVersion,
        hasApkDownloadUrl: hasApkDownloadUrl,
        onUpdate: onUpdate,
      ),
      UpdateCheckStatus.error => _RetryView(label: '확인 실패', onRetry: onCheck),
      UpdateCheckStatus.downloading => _DownloadingView(
        percent: downloadProgress?.percent ?? 0,
        onCancel: onCancelDownload,
      ),
      UpdateCheckStatus.downloadError => _RetryView(
        label: '다운로드 실패',
        onRetry: onRetryDownload,
      ),
      UpdateCheckStatus.readyToInstall => _InstallView(
        label: '다운로드 완료',
        onInstall: onInstall,
      ),
      UpdateCheckStatus.installPermissionRequired => _InstallView(
        label: '설치 권한 필요',
        buttonLabel: '설정 열기',
        onInstall: onOpenPermissionSettings,
      ),
    };
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({this.onCheck});
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p8,
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(onPressed: onCheck, child: const Text('업데이트 확인')),
      ),
    );
  }
}

class _CheckingView extends StatelessWidget {
  const _CheckingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p12,
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _UpToDateView extends StatelessWidget {
  const _UpToDateView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p8,
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.p8),
          Text('최신 버전입니다', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AvailableView extends StatelessWidget {
  const _AvailableView({
    required this.newVersion,
    required this.hasApkDownloadUrl,
    this.onUpdate,
  });
  final String? newVersion;
  final bool hasApkDownloadUrl;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: AppRadius.borderRadiusLg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.p12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'v$newVersion 사용 가능',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onUpdate,
                child: Text(hasApkDownloadUrl ? '업데이트' : '브라우저에서 열기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.percent, this.onCancel});
  final int percent;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: AppRadius.borderRadiusLg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.p12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '다운로드 중 $percent%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  _CancelChip(onCancel: onCancel),
                ],
              ),
              const SizedBox(height: AppSpacing.p8),
              ClipRRect(
                borderRadius: AppRadius.borderRadiusSm,
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelChip extends StatelessWidget {
  const _CancelChip({this.onCancel});
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppSizes.minTouchTarget,
        minHeight: AppSizes.minTouchTarget,
      ),
      child: InkWell(
        onTap: onCancel,
        borderRadius: AppRadius.borderRadiusSm,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.p8),
          child: Text('취소'),
        ),
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.label, this.onRetry});
  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p8,
      ),
      child: InkWell(
        onTap: onRetry,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.p8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: AppSpacing.p4),
              Text(
                '다시 시도',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstallView extends StatelessWidget {
  const _InstallView({
    required this.label,
    this.buttonLabel = '설치',
    this.onInstall,
  });
  final String label;
  final String buttonLabel;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p16,
        vertical: AppSpacing.p8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: AppRadius.borderRadiusLg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.p12),
          child: Row(
            children: [
              Icon(
                Icons.system_update,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.p8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              FilledButton(onPressed: onInstall, child: Text(buttonLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
