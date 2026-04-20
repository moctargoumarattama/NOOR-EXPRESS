import 'package:image_picker/image_picker.dart';

import 'photo_picker_types.dart';

Future<NoorPickedPhoto?> pickPhoto({
  required NoorPhotoSource source,
  required bool preferFrontCamera,
  required double? maxWidth,
  required int imageQuality,
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
    return NoorPickedPhoto(bytes: await file.readAsBytes(), name: file.name);
  } catch (error) {
    throw NoorPhotoPickerFailure('Selection photo impossible: $error');
  }
}
