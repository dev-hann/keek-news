import 'package:dartz/dartz.dart' show Either, Unit;
import 'package:flutter/material.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/copy_media_url_use_case.dart';
import 'package:keek_news/use_case/save_media_use_case.dart';
import 'package:keek_news/use_case/share_media_use_case.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Signature for save/share actions. [onProgress] streams download progress
/// back to the sheet while the returned future resolves the final outcome.
typedef MediaActionCallback =
    Future<Either<MediaSaveFailure, Unit>> Function(
      void Function(DownloadProgress progress)? onProgress,
    );

/// Presents the long-press action sheet (저장 / 공유 / URL 복사) for [target].
///
/// Use cases default to the DI container; tests may inject fakes.
Future<void> showMediaActionSheet(
  BuildContext context, {
  required MediaTarget target,
  SaveMediaUseCase? saveUseCase,
  ShareMediaUseCase? shareUseCase,
  CopyMediaUrlUseCase? copyUseCase,
}) {
  final save = saveUseCase ?? sl<SaveMediaUseCase>();
  final share = shareUseCase ?? sl<ShareMediaUseCase>();
  final copy = copyUseCase ?? const CopyMediaUrlUseCase();
  return showModalBottomSheet<void>(
    context: context,
    // Sheet chrome stays Material-side: ShadSheet relies on ShadApp root
    // wiring that conflicts with the current router setup (same call as the
    // comments sheet). Content is styled with ShadTheme tokens.
    backgroundColor: ShadTheme.of(context).colorScheme.card,
    builder: (_) => MediaActionSheet(
      target: target,
      onSave: (onProgress) => save(target, onProgress: onProgress),
      onShare: (onProgress) => share(target, onProgress: onProgress),
      onCopyUrl: () => copy(target),
      onCancelDownload: () {
        save.cancel(target);
        share.cancel(target);
      },
    ),
  );
}

enum _ActionPhase { idle, running, error }

class MediaActionSheet extends StatefulWidget {
  const MediaActionSheet({
    required this.target,
    required this.onSave,
    required this.onShare,
    required this.onCopyUrl,
    required this.onCancelDownload,
    super.key,
  });

  final MediaTarget target;
  final MediaActionCallback onSave;
  final MediaActionCallback onShare;
  final Future<void> Function() onCopyUrl;

  /// Cancels any in-flight download. Called when the sheet is dismissed
  /// mid-download (v1 keeps downloads alive only while the sheet is open) and
  /// when the user taps a progress row.
  final VoidCallback onCancelDownload;

  @override
  State<MediaActionSheet> createState() => _MediaActionSheetState();
}

class _MediaActionSheetState extends State<MediaActionSheet> {
  _ActionPhase _savePhase = _ActionPhase.idle;
  _ActionPhase _sharePhase = _ActionPhase.idle;
  DownloadProgress? _saveProgress;
  DownloadProgress? _shareProgress;

  @override
  void dispose() {
    widget.onCancelDownload();
    super.dispose();
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _closeSheet() {
    Navigator.of(context).pop();
  }

  Future<void> _runSave() async {
    if (_savePhase == _ActionPhase.running) return;
    setState(() {
      _savePhase = _ActionPhase.running;
      _saveProgress = null;
    });
    final result = await widget.onSave(_onSaveProgress);
    if (!mounted) return;
    final failure = result.fold((MediaSaveFailure f) => f, (_) => null);
    if (failure == null) {
      _showSnackbar('저장했어요');
      _closeSheet();
      return;
    }
    switch (failure.type) {
      case MediaSaveFailureType.canceled:
      case MediaSaveFailureType.inProgress:
        setState(() => _savePhase = _ActionPhase.idle);
      case MediaSaveFailureType.permission:
        // Permission needs a system-settings trip; the sheet has nothing
        // more to offer inline.
        setState(() => _savePhase = _ActionPhase.idle);
        _showSnackbar('갤러리 접근 권한이 필요해요. 시스템 설정에서 허용해주세요');
        _closeSheet();
      case MediaSaveFailureType.network:
      case MediaSaveFailureType.unexpected:
        setState(() => _savePhase = _ActionPhase.error);
    }
  }

  void _onSaveProgress(DownloadProgress progress) {
    if (!mounted) return;
    setState(() => _saveProgress = progress);
  }

  void _onShareProgress(DownloadProgress progress) {
    if (!mounted) return;
    setState(() => _shareProgress = progress);
  }

  Future<void> _runShare() async {
    if (_sharePhase == _ActionPhase.running) return;
    setState(() {
      _sharePhase = _ActionPhase.running;
      _shareProgress = null;
    });
    final result = await widget.onShare(_onShareProgress);
    if (!mounted) return;
    final failure = result.fold((MediaSaveFailure f) => f, (_) => null);
    if (failure == null) {
      // The system share sheet is now up; close ours.
      _closeSheet();
      return;
    }
    setState(() {
      _sharePhase = switch (failure.type) {
        MediaSaveFailureType.canceled ||
        MediaSaveFailureType.inProgress => _ActionPhase.idle,
        _ => _ActionPhase.error,
      };
    });
  }

  Future<void> _runCopy() async {
    await widget.onCopyUrl();
    if (!mounted) return;
    _showSnackbar('링크를 복사했어요');
    _closeSheet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final rows = <Widget>[
      if (widget.target.isDownloadable) ...[
        _buildSaveRow(theme),
        Divider(height: 1, color: theme.colorScheme.border),
      ],
      _buildShareRow(theme),
      Divider(height: 1, color: theme.colorScheme.border),
      _buildCopyRow(theme),
    ];
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _buildSaveRow(ShadThemeData theme) {
    final isVideo = widget.target.kind == MediaKind.video;
    return switch (_savePhase) {
      _ActionPhase.running => _ProgressRow(
        label: _progressLabel('저장 중…', _saveProgress),
        onTap: widget.onCancelDownload,
        progress: _saveProgress,
      ),
      _ActionPhase.error => _ActionRow(
        icon: LucideIcons.alertCircle,
        label: '저장에 실패했어요 · 탭하여 재시도',
        semanticsLabel: '저장 실패, 탭하여 재시도',
        onTap: _runSave,
        foreground: theme.colorScheme.destructive,
      ),
      _ActionPhase.idle => _ActionRow(
        icon: isVideo ? LucideIcons.download : LucideIcons.imageDown,
        label: '갤러리에 저장',
        semanticsLabel: '갤러리에 저장',
        onTap: _runSave,
      ),
    };
  }

  Widget _buildShareRow(ShadThemeData theme) {
    return switch (_sharePhase) {
      _ActionPhase.running => _ProgressRow(
        label: _progressLabel('준비 중…', _shareProgress),
        // Sharing has no separate cancel: the row mirrors the download
        // cancel like the save row.
        onTap: widget.onCancelDownload,
        progress: _shareProgress,
      ),
      _ActionPhase.error => _ActionRow(
        icon: LucideIcons.alertCircle,
        label: '공유에 실패했어요 · 탭하여 재시도',
        semanticsLabel: '공유 실패, 탭하여 재시도',
        onTap: _runShare,
        foreground: theme.colorScheme.destructive,
      ),
      _ActionPhase.idle => _ActionRow(
        icon: LucideIcons.share2,
        label: '공유',
        semanticsLabel: '공유',
        onTap: _runShare,
      ),
    };
  }

  Widget _buildCopyRow(ShadThemeData theme) {
    return _ActionRow(
      icon: LucideIcons.link,
      label: 'URL 복사',
      semanticsLabel: 'URL 복사',
      onTap: _runCopy,
    );
  }

  String _progressLabel(String prefix, DownloadProgress? progress) {
    if (progress == null || progress.isUnknownSize) return prefix;
    return '$prefix ${progress.percent}%';
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = foreground ?? theme.colorScheme.foreground;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.p.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.onTap,
    required this.progress,
  });

  final String label;
  final VoidCallback onTap;
  final DownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final progress = this.progress;
    final known = progress != null && !progress.isUnknownSize;
    return Semantics(
      button: true,
      label: '$label, 탭하여 취소',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.p.copyWith(
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                    ),
                    Text(
                      '취소',
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: known ? progress.percent / 100 : null,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
