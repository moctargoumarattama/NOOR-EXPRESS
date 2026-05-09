import 'package:dio/dio.dart';

import '../constants/app_messages.dart';

enum ApiIssueType {
  offline,
  timeout,
  serverUnavailable,
  unknown,
}

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
    final issue = classifyDio(error);
    final issueMessage = _issueMessage(issue);
    if (issueMessage != null) {
      return issueMessage;
    }

    final payload = fromDio(error);
    final localized = _localizedMessage(payload);
    if (localized != null && localized.trim().isNotEmpty) {
      return localized;
    }

    final message = payload.message;
    if (message == null || message.trim().isEmpty) {
      return fallbackMessage;
    }
    return message;
  }

  static ApiIssueType classifyDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiIssueType.timeout;
      case DioExceptionType.connectionError:
        return ApiIssueType.offline;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode >= 500) {
          return ApiIssueType.serverUnavailable;
        }
        return ApiIssueType.unknown;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        final fallback = classifyMessage(error.message);
        if (fallback != ApiIssueType.unknown) {
          return fallback;
        }
        return ApiIssueType.unknown;
    }
  }

  static ApiIssueType classifyMessage(String? message) {
    final value = _normalizeMessage(message);
    if (value == null) {
      return ApiIssueType.unknown;
    }
    if (value.contains('timeout') ||
        value.contains('timed out') ||
        value.contains('delai') ||
        value.contains('temps')) {
      return ApiIssueType.timeout;
    }
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connexion') ||
        value.contains('internet') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused')) {
      return ApiIssueType.offline;
    }
    if (value.contains('service indisponible') ||
        value.contains('serveur indisponible') ||
        value.contains('server error') ||
        value.contains('service unavailable') ||
        value.contains('internal server error') ||
        value.contains('gateway')) {
      return ApiIssueType.serverUnavailable;
    }
    return ApiIssueType.unknown;
  }

  static String? _issueMessage(ApiIssueType issue) {
    switch (issue) {
      case ApiIssueType.offline:
        return AppMessages.apiOffline;
      case ApiIssueType.timeout:
        return AppMessages.apiTimeout;
      case ApiIssueType.serverUnavailable:
        return AppMessages.apiServerUnavailable;
      case ApiIssueType.unknown:
        return null;
    }
  }

  static String? _localizedMessage(ApiErrorPayload payload) {
    final normalizedMessage = _normalizeMessage(payload.message);
    if (normalizedMessage != null) {
      final localizedByText = _localizedMessagesByText[normalizedMessage];
      if (localizedByText != null) {
        return localizedByText;
      }
    }

    final code = payload.code?.trim().toLowerCase();
    if (code != null && code.isNotEmpty) {
      final localizedByCode = _localizedMessagesByCode[code];
      if (localizedByCode != null) {
        return localizedByCode;
      }
    }

    return null;
  }

  static String? _normalizeMessage(String? message) {
    final value = message?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.endsWith('.') ? value.substring(0, value.length - 1) : value;
  }

  static const Map<String, String> _localizedMessagesByCode = {
    'bad_request': AppMessages.apiBadRequest,
    'unauthorized': AppMessages.apiUnauthorized,
    'f\u006frbidden': AppMessages.apiForbidden,
    'not_found': AppMessages.apiNotFound,
    'client_already_has_active_ride': AppMessages.apiRideAlreadyActive,
    'driver_already_has_active_ride': AppMessages.apiRideAlreadyActive,
    'offer_expired': AppMessages.apiOfferExpired,
    'offer_already_resolved': AppMessages.apiOfferAlreadyResolved,
    'offer_already_exists': AppMessages.apiOfferAlreadyExists,
    'ride_already_assigned': AppMessages.apiRideAlreadyAssigned,
    'ride_not_negotiable': AppMessages.apiRideNotNegotiable,
    'ride_transition_not_allowed': AppMessages.apiRideTransitionNotAllowed,
    'price_locked': AppMessages.apiPriceLocked,
    'ride_already_expired': AppMessages.apiRideAlreadyExpired,
    'ride_cancellation_not_allowed': AppMessages.apiRideCancellationNotAllowed,
    'driver_cannot_cancel_started_ride': AppMessages.apiDriverCancelStartedRide,
  };

  static const Map<String, String> _localizedMessagesByText = {};
}
