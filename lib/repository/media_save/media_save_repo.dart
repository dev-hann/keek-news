import 'package:dartz/dartz.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';

abstract class MediaSaveRepo {
  /// Downloads the image at [url] and saves it to the device gallery.
  Future<Either<MediaSaveFailure, Unit>> saveImage(
    String url, {
    void Function(DownloadProgress progress)? onProgress,
  });

  /// Downloads the video at [url] and saves it to the device gallery.
  Future<Either<MediaSaveFailure, Unit>> saveVideo(
    String url, {
    void Function(DownloadProgress progress)? onProgress,
  });

  /// Shares [target] through the system share sheet: the downloaded file when
  /// possible, the URL as text for external embeds or as a fallback when the
  /// download fails.
  Future<Either<MediaSaveFailure, Unit>> share(
    MediaTarget target, {
    void Function(DownloadProgress progress)? onProgress,
  });

  /// Cancels any in-flight download for [url]. No-op when none is running.
  void cancel(String url);
}
