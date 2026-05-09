// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'photo_picker_types.dart';

const _optimizedPhotoFallbackMaxBytes = 900 * 1024;

Future<NoorPickedPhoto?> pickPhoto({
  required NoorPhotoSource source,
  required bool preferFrontCamera,
  required double? maxWidth,
  required int imageQuality,
  required int targetMaxBytes,
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

    final bytes = await _readOptimizedBytes(
      file: file,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
      targetMaxBytes: targetMaxBytes,
    );
    return NoorPickedPhoto(bytes: bytes, name: file.name);
  } on TimeoutException {
    throw const NoorPhotoPickerFailure('Selection photo expiree.');
  } on NoorPhotoPickerFailure {
    rethrow;
  } catch (error) {
    throw NoorPhotoPickerFailure('Selection photo impossible: $error');
  }
}

Future<Uint8List> _readOptimizedBytes({
  required html.File file,
  required double? maxWidth,
  required int imageQuality,
  required int targetMaxBytes,
}) async {
  final originalBytes = await _fileToBytes(file);
  final maxBytes = targetMaxBytes > 0
      ? targetMaxBytes
      : _optimizedPhotoFallbackMaxBytes;

  // Keep behavior safe: if optimization cannot run, return original bytes.
  try {
    final dataUrl = await _fileToDataUrl(file);
    final image = await _loadImage(dataUrl);
    final sourceWidth = image.naturalWidth;
    final sourceHeight = image.naturalHeight;
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return originalBytes;
    }

    final baseWidth = _scaledWidth(sourceWidth, maxWidth);
    final widths = <int>[
      baseWidth,
      (baseWidth * 0.85).round(),
      (baseWidth * 0.72).round(),
      (baseWidth * 0.60).round(),
    ].map((value) => value.clamp(1, sourceWidth)).toSet().toList();
    final qualities = <int>[
      imageQuality.clamp(1, 100),
      55,
      45,
      35,
    ];

    Uint8List? smallestBytes;
    for (var i = 0; i < widths.length && i < qualities.length; i++) {
      final targetWidth = widths[i];
      final targetHeight = (((sourceHeight / sourceWidth) * targetWidth)
          .round()
          .clamp(1, 100000));
      final bytes = await _renderJpegBytes(
        image: image,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        quality: qualities[i] / 100,
      );
      if (bytes == null) {
        continue;
      }
      if (smallestBytes == null || bytes.length < smallestBytes.length) {
        smallestBytes = bytes;
      }
      if (bytes.length <= maxBytes) {
        return bytes;
      }
    }
    final bestBytes = smallestBytes ?? originalBytes;
    if (bestBytes.length <= maxBytes) {
      return bestBytes;
    }
    final maxKb = maxBytes ~/ 1024;
    throw NoorPhotoPickerFailure(
      'Image trop lourde (${bestBytes.length ~/ 1024} KB). Visez moins de $maxKb KB.',
    );
  } catch (_) {
    if (originalBytes.length <= maxBytes) {
      return originalBytes;
    }
    final maxKb = maxBytes ~/ 1024;
    throw NoorPhotoPickerFailure(
      'Image trop lourde (${originalBytes.length ~/ 1024} KB). Visez moins de $maxKb KB.',
    );
  }
}

int _scaledWidth(int sourceWidth, double? maxWidth) {
  if (maxWidth == null || maxWidth <= 0) {
    return sourceWidth;
  }
  final limit = maxWidth.round();
  return sourceWidth > limit ? limit : sourceWidth;
}

Future<Uint8List> _fileToBytes(html.File file) async {
  final reader = html.FileReader()..readAsArrayBuffer(file);
  await reader.onLoad.first.timeout(const Duration(seconds: 30));
  final result = reader.result;
  if (result is ByteBuffer) {
    return Uint8List.view(result);
  }
  if (result is Uint8List) {
    return result;
  }
  throw const NoorPhotoPickerFailure('Image web illisible.');
}

Future<String> _fileToDataUrl(html.File file) async {
  final reader = html.FileReader()..readAsDataUrl(file);
  await reader.onLoad.first.timeout(const Duration(seconds: 30));
  final result = reader.result;
  if (result is String && result.isNotEmpty) {
    return result;
  }
  throw const NoorPhotoPickerFailure('Image web illisible.');
}

Future<html.ImageElement> _loadImage(String dataUrl) async {
  final image = html.ImageElement(src: dataUrl);
  await image.onLoad.first.timeout(const Duration(seconds: 30));
  return image;
}

Future<html.Blob?> _canvasToBlob(html.CanvasElement canvas, double quality) {
  return canvas
      .toBlob('image/jpeg', quality)
      .timeout(const Duration(seconds: 10));
}

Future<Uint8List?> _renderJpegBytes({
  required html.ImageElement image,
  required int targetWidth,
  required int targetHeight,
  required double quality,
}) async {
  final canvas = html.CanvasElement(
    width: targetWidth,
    height: targetHeight,
  );
  final context = canvas.context2D;
  context.imageSmoothingEnabled = true;
  context.imageSmoothingQuality = 'high';
  context.drawImageScaled(
    image,
    0,
    0,
    targetWidth.toDouble(),
    targetHeight.toDouble(),
  );

  final blob = await _canvasToBlob(canvas, quality);
  if (blob == null) {
    return null;
  }
  return _blobToBytes(blob);
}

Future<Uint8List> _blobToBytes(html.Blob blob) async {
  final reader = html.FileReader()..readAsArrayBuffer(blob);
  await reader.onLoad.first.timeout(const Duration(seconds: 30));
  final result = reader.result;
  if (result is ByteBuffer) {
    return Uint8List.view(result);
  }
  if (result is Uint8List) {
    return result;
  }
  throw const NoorPhotoPickerFailure('Image web illisible.');
}
