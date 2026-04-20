import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_picker_impl.dart' if (dart.library.html) 'photo_picker_web.dart'
    as platform;
import 'photo_picker_types.dart';

export 'photo_picker_types.dart';

class NoorPhotoPickerService {
  Future<NoorPickedPhoto?> pickPhoto({
    required NoorPhotoSource source,
    bool preferFrontCamera = false,
    double? maxWidth,
    int imageQuality = 75,
  }) {
    return platform.pickPhoto(
      source: source,
      preferFrontCamera: preferFrontCamera,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  }
}

final noorPhotoPickerServiceProvider = Provider<NoorPhotoPickerService>((ref) {
  return NoorPhotoPickerService();
});
