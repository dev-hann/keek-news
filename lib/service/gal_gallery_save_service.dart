import 'package:gal/gal.dart';
import 'package:keek_news/service/gallery_save_service.dart';

class GalGallerySaveService implements GallerySaveService {
  const GalGallerySaveService();

  @override
  Future<void> putImage(String path) => _guard(() => Gal.putImage(path));

  @override
  Future<void> putVideo(String path) => _guard(() => Gal.putVideo(path));

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on GalException catch (e) {
      throw GallerySaveException(
        permissionDenied: e.type == GalExceptionType.accessDenied,
      );
    }
  }
}
