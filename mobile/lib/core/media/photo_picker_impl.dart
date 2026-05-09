import 'package:image_picker/image_picker.dart';

import 'photo_picker_types.dart';

Future<NoorPickedPhoto?> pickPhoto({
  required NoorPhotoSource source,
  required bool preferFrontCamera,
  required double? maxWidth,
  required int imageQuality,
  required int targetMaxBytes,
}) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source == NoorPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      preferredCameraDevice:
          preferFrontCamera ? CameraDevice.front : CameraDevice.rear,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > targetMaxBytes) {
      final maxKb = targetMaxBytes ~/ 1024;
      throw NoorPhotoPickerFailure(
        'Image trop lourde (${bytes.length ~/ 1024} KB). Visez moins de $maxKb KB.',
      );
    }
    return NoorPickedPhoto(bytes: bytes, name: file.name);
  } on NoorPhotoPickerFailure {
    rethrow;
  } catch (error) {
    throw NoorPhotoPickerFailure('Selection photo impossible: $error');
  }
}
