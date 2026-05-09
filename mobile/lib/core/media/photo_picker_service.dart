import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_picker_impl.dart' if (dart.library.html) 'photo_picker_web.dart'
    as platform;
import 'photo_picker_types.dart';

export 'photo_picker_types.dart';

const _defaultCompressedImageMaxWidth = 720.0;
const _defaultCompressedImageQuality = 60;
const _minimumCompressedImageQuality = 20;
const _maximumCompressedImageQuality = 85;
const _defaultTargetMaxBytes = 900 * 1024;

class NoorPhotoPickerService {
  Future<NoorPickedPhoto?> pickPhoto({
    required NoorPhotoSource source,
    bool preferFrontCamera = false,
    double? maxWidth,
    int imageQuality = _defaultCompressedImageQuality,
    int targetMaxBytes = _defaultTargetMaxBytes,
  }) {
    final normalizedQuality = imageQuality.clamp(
      _minimumCompressedImageQuality,
      _maximumCompressedImageQuality,
    );
    final normalizedMaxWidth = maxWidth == null || maxWidth <= 0
        ? _defaultCompressedImageMaxWidth
        : maxWidth;
    return platform.pickPhoto(
      source: source,
      preferFrontCamera: preferFrontCamera,
      maxWidth: normalizedMaxWidth,
      imageQuality: normalizedQuality,
      targetMaxBytes: targetMaxBytes,
    );
  }
}

final noorPhotoPickerServiceProvider = Provider<NoorPhotoPickerService>((ref) {
  return NoorPhotoPickerService();
});
