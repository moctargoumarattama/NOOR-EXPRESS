import 'dart:typed_data';

enum NoorPhotoSource {
  camera,
  gallery,
}

class NoorPickedPhoto {
  const NoorPickedPhoto({
    required this.bytes,
    this.name,
  });

  final Uint8List bytes;
  final String? name;
}

class NoorPhotoPickerFailure implements Exception {
  const NoorPhotoPickerFailure(this.message);

  final String message;
}
