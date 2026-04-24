import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/tracking_status_presenter.dart';

RideTrackingModel _ride({
  required RideTrackingStatus status,
  String? cancellationReason,
}) {
  return RideTrackingModel(
    id: 1,
    clientId: 10,
    driverId: 20,
    pickupLocation: 'Grand Marche',
    dropoffLocation: 'Aeroport',
    estimatedPrice: 2500,
    createdAt: DateTime(2026, 4, 23),
    status: status,
    cancellationReason: cancellationReason,
  );
}

void main() {
  group('buildClientTrackingStatusPresentation', () {
    test('shows searching state while ride is still pending', () {
      final presentation = buildClientTrackingStatusPresentation(
        _ride(status: RideTrackingStatus.pending),
      );

      expect(presentation.title, 'Recherche de chauffeur');
      expect(presentation.showSpinner, isTrue);
    });

    test('shows offered state clearly before acceptance', () {
      final presentation = buildClientTrackingStatusPresentation(
        _ride(status: RideTrackingStatus.offered),
      );

      expect(presentation.title, 'Offres disponibles');
      expect(
        presentation.subtitle,
        'Consultez les propositions recues avant de confirmer.',
      );
      expect(presentation.showSpinner, isTrue);
    });

    test('shows cancelled state with reason when present', () {
      final presentation = buildClientTrackingStatusPresentation(
        _ride(
          status: RideTrackingStatus.cancelled,
          cancellationReason: 'Client indisponible',
        ),
      );

      expect(presentation.title, 'Course annulee');
      expect(
        presentation.subtitle,
        'Raison: Client indisponible',
      );
      expect(presentation.showSpinner, isFalse);
    });

    test('shows expired state without pretending the ride is still searching',
        () {
      final presentation = buildClientTrackingStatusPresentation(
        _ride(status: RideTrackingStatus.expired),
      );

      expect(presentation.title, 'Demande expiree');
      expect(
        presentation.subtitle,
        'Aucun chauffeur n a confirme a temps. Vous pouvez relancer une demande.',
      );
      expect(presentation.showSpinner, isFalse);
    });
  });

  group('buildDriverTrackingStatusPresentation', () {
    test('shows accepted state for driver clearly', () {
      final presentation = buildDriverTrackingStatusPresentation(
        _ride(status: RideTrackingStatus.accepted),
      );

      expect(presentation.title, 'Direction le client');
      expect(presentation.subtitle, 'Rendez-vous a Grand Marche.');
      expect(presentation.showSpinner, isFalse);
    });
  });
}
