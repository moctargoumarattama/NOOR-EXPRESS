import 'package:dio/dio.dart';

class ApiErrorPayload {
  const ApiErrorPayload({
    this.code,
    this.message,
  });

  final String? code;
  final String? message;

  static ApiErrorPayload fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['code'] as String?;
      final message = data['message'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return ApiErrorPayload(code: code, message: message);
      }

      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return ApiErrorPayload(code: code, message: detail);
      }
    }
    return const ApiErrorPayload();
  }

  static String messageOrFallback(
    DioException error, {
    required String fallbackMessage,
  }) {
    final payload = fromDio(error);
    final message = payload.message;
    if (message == null || message.trim().isEmpty) {
      return fallbackMessage;
    }
    return message;
  }
}
