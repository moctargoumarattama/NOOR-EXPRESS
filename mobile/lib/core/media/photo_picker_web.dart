// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'photo_picker_types.dart';

Future<NoorPickedPhoto?> pickPhoto({
  required NoorPhotoSource source,
  required bool preferFrontCamera,
  required double? maxWidth,
  required int imageQuality,
}) async {
  try {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..style.display = 'none';

    // Sur web, le meme selecteur ouvre la galerie. Si le navigateur accepte
    // "capture", il proposera directement la camera.
    if (source == NoorPhotoSource.camera) {
      input.setAttribute('capture', preferFrontCamera ? 'user' : 'environment');
    }

    html.document.body?.append(input);
    input.click();

    await input.onChange.first.timeout(const Duration(minutes: 2));
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    input.remove();
    if (file == null) {
      return null;
    }

    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoad.first.timeout(const Duration(seconds: 30));
    final result = reader.result;
    if (result is ByteBuffer) {
      return NoorPickedPhoto(bytes: Uint8List.view(result), name: file.name);
    }
    if (result is Uint8List) {
      return NoorPickedPhoto(bytes: result, name: file.name);
    }
    throw const NoorPhotoPickerFailure('Image web illisible.');
  } on TimeoutException {
    throw const NoorPhotoPickerFailure('Selection photo expiree.');
  } catch (error) {
    throw NoorPhotoPickerFailure('Selection photo impossible: $error');
  }
}
