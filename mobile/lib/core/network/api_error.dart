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
    'bad_request': 'Requete invalide.',
    'unauthorized': 'Authentification requise.',
    'forbidden': 'Acces refuse.',
    'not_found': 'Element introuvable.',
    'client_already_has_active_ride': 'Vous avez deja une course en cours.',
    'driver_already_has_active_ride': 'Vous avez deja une course en cours.',
    'offer_expired': 'Cette proposition n est plus disponible.',
    'offer_already_resolved': 'Cette proposition a deja ete traitee.',
    'offer_already_exists': 'Vous avez deja repondu a cette course.',
    'ride_already_assigned': 'Cette course a deja une offre acceptee.',
    'ride_not_negotiable': 'Cette course n est plus negociable.',
    'ride_transition_not_allowed':
        'Cette action n est pas autorisee pour le statut actuel.',
    'price_locked': 'Le prix de cette course est deja verrouille.',
    'ride_already_expired': 'Cette course a deja expire.',
    'ride_cancellation_not_allowed':
        'Cette annulation n est pas autorisee pour le moment.',
    'driver_cannot_cancel_started_ride':
        'Le chauffeur ne peut pas annuler une course deja demarree.',
  };

  static const Map<String, String> _localizedMessagesByText = {
    'authentication required': 'Authentification requise.',
    'access denied': 'Acces refuse.',
    'client access required': 'Acces client requis.',
    'driver access required': 'Acces chauffeur requis.',
    'ride request not found': 'Course introuvable.',
    'offer not found': 'Offre introuvable.',
    'driver not found': 'Chauffeur introuvable.',
    'driver is not assigned to this ride':
        'Ce chauffeur n est pas assigne a cette course.',
    'ride negotiation has expired': 'La negociation de cette course a expire.',
    'ride is no longer negotiable': 'Cette course n est plus negociable.',
    'client already has an active ride':
        'Vous avez deja une course en cours.',
    'driver already has an active ride':
        'Vous avez deja une course en cours.',
    'driver has already responded to this ride':
        'Vous avez deja repondu a cette course.',
    'offer has expired': 'Cette proposition n est plus disponible.',
    'offer has already been resolved':
        'Cette proposition a deja ete traitee.',
    'ride already has a winning offer':
        'Cette course a deja une offre acceptee.',
    'ride is not started': 'La course n a pas encore commence.',
    'ride price is locked after offer acceptance':
        'Le prix de cette course est deja verrouille.',
    'ride has already expired': 'Cette course a deja expire.',
    'client cannot cancel this ride at the current status':
        'Cette course ne peut pas etre annulee pour le moment.',
    'driver cannot cancel a started ride':
        'Le chauffeur ne peut pas annuler une course deja demarree.',
    'driver cancellation is not allowed at the current status':
        'Le chauffeur ne peut pas annuler cette course pour le moment.',
  };
}
