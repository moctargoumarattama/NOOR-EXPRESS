import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/network/api_error.dart';

void main() {
  group('ApiErrorPayload.messageOrFallback', () {
    test('explains that the backend is unreachable on connection errors', () {
      final error = DioException.connectionError(
        requestOptions: RequestOptions(path: '/ride-requests/'),
        reason: 'Failed host lookup',
      );

      final message = ApiErrorPayload.messageOrFallback(
        error,
        fallbackMessage: 'Creation impossible.',
      );

      expect(
        message,
        'Impossible de joindre le backend Noor Express. Verifiez votre connexion ou l URL de l API.',
      );
    });

    test('translates active ride conflict to French', () {
      final error = _dioError(
        code: 'client_already_has_active_ride',
        message: 'Client already has an active ride.',
      );

      final message = ApiErrorPayload.messageOrFallback(
        error,
        fallbackMessage: 'Creation impossible.',
      );

      expect(message, 'Vous avez deja une course en cours.');
    });

    test('translates known English backend messages even without a code', () {
      final error = _dioError(
        message: 'Ride request not found',
      );

      final message = ApiErrorPayload.messageOrFallback(
        error,
        fallbackMessage: 'Course introuvable.',
      );

      expect(message, 'Course introuvable.');
    });

    test('keeps French backend messages unchanged', () {
      final error = _dioError(
        code: 'ride_cancelled',
        message: 'Course annulee par le client.',
      );

      final message = ApiErrorPayload.messageOrFallback(
        error,
        fallbackMessage: 'Action impossible.',
      );

      expect(message, 'Course annulee par le client.');
    });
  });
}

DioException _dioError({
  String? code,
  required String message,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/ride-requests/'),
    response: Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/ride-requests/'),
      data: {
        if (code != null) 'code': code,
        'message': message,
      },
    ),
  );
}
