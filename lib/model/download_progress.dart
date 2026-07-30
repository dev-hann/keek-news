import 'package:equatable/equatable.dart';

class DownloadProgress extends Equatable {
  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });
  final int receivedBytes;
  final int totalBytes;

  bool get isUnknownSize => totalBytes <= 0;

  int get percent {
    if (isUnknownSize || receivedBytes <= 0) return 0;
    final ratio = receivedBytes / totalBytes;
    if (ratio >= 1) return 100;
    return (ratio * 100).clamp(0, 100).round();
  }

  @override
  List<Object?> get props => [receivedBytes, totalBytes];
}
