import '../data/models/ride_tracking_model.dart';

class TrackingStatusPresentation {
  const TrackingStatusPresentation({
    required this.title,
    required this.subtitle,
    required this.showSpinner,
  });

  final String title;
  final String subtitle;
  final bool showSpinner;
}

TrackingStatusPresentation buildClientTrackingStatusPresentation(
  RideTrackingModel? ride,
) {
  if (ride == null) {
    return const TrackingStatusPresentation(
      title: 'Suivi de course',
      subtitle: 'Nous remettons votre course a jour.',
      showSpinner: false,
    );
  }

  switch (ride.status) {
    case RideTrackingStatus.pending:
      return const TrackingStatusPresentation(
        title: 'Recherche de chauffeur',
        subtitle: 'Nous contactons les chauffeurs proches de vous.',
        showSpinner: true,
      );
    case RideTrackingStatus.offered:
      return const TrackingStatusPresentation(
        title: 'Offres disponibles',
        subtitle: 'Consultez les propositions recues avant de confirmer.',
        showSpinner: true,
      );
    case RideTrackingStatus.accepted:
      return const TrackingStatusPresentation(
        title: 'Chauffeur confirme',
        subtitle: 'Votre chauffeur arrive vers le point de depart.',
        showSpinner: false,
      );
    case RideTrackingStatus.arrived:
      return const TrackingStatusPresentation(
        title: 'Chauffeur sur place',
        subtitle: 'Rejoignez le point de prise en charge pour demarrer.',
        showSpinner: false,
      );
    case RideTrackingStatus.started:
      return TrackingStatusPresentation(
        title: 'Course en cours',
        subtitle: 'Suivez le trajet jusqu a ${ride.dropoffLocation}.',
        showSpinner: false,
      );
    case RideTrackingStatus.completed:
      return const TrackingStatusPresentation(
        title: 'Course terminee',
        subtitle: 'Vous etes arrive a destination.',
        showSpinner: false,
      );
    case RideTrackingStatus.cancelled:
      final reason = ride.cancellationReason?.trim();
      return TrackingStatusPresentation(
        title: 'Course annulee',
        subtitle: reason == null || reason.isEmpty
            ? 'Cette course a ete annulee.'
            : 'Raison: $reason',
        showSpinner: false,
      );
    case RideTrackingStatus.expired:
      return const TrackingStatusPresentation(
        title: 'Demande expiree',
        subtitle:
            'Aucun chauffeur n a confirme a temps. Vous pouvez relancer une demande.',
        showSpinner: false,
      );
    case RideTrackingStatus.unknown:
      return const TrackingStatusPresentation(
        title: 'Synchronisation du statut',
        subtitle: 'Le suivi revient progressivement a jour.',
        showSpinner: false,
      );
  }
}

TrackingStatusPresentation buildDriverTrackingStatusPresentation(
  RideTrackingModel? ride,
) {
  if (ride == null) {
    return const TrackingStatusPresentation(
      title: 'Suivi de course',
      subtitle: 'Nous remettons la course a jour.',
      showSpinner: false,
    );
  }

  switch (ride.status) {
    case RideTrackingStatus.pending:
    case RideTrackingStatus.offered:
      return const TrackingStatusPresentation(
        title: 'Demande en attente',
        subtitle: 'Cette demande n est pas encore confirmee.',
        showSpinner: true,
      );
    case RideTrackingStatus.accepted:
      return TrackingStatusPresentation(
        title: 'Direction le client',
        subtitle: 'Rendez-vous a ${ride.pickupLocation}.',
        showSpinner: false,
      );
    case RideTrackingStatus.arrived:
      return const TrackingStatusPresentation(
        title: 'Client attendu',
        subtitle: 'Le client peut maintenant confirmer qu il est pret.',
        showSpinner: false,
      );
    case RideTrackingStatus.started:
      return TrackingStatusPresentation(
        title: 'Course en cours',
        subtitle: 'Suivez le trajet jusqu a ${ride.dropoffLocation}.',
        showSpinner: false,
      );
    case RideTrackingStatus.completed:
      return const TrackingStatusPresentation(
        title: 'Course terminee',
        subtitle: 'Vous pouvez finaliser le paiement et revenir a l accueil.',
        showSpinner: false,
      );
    case RideTrackingStatus.cancelled:
      final reason = ride.cancellationReason?.trim();
      return TrackingStatusPresentation(
        title: 'Course annulee',
        subtitle: reason == null || reason.isEmpty
            ? 'Cette course a ete annulee.'
            : 'Raison: $reason',
        showSpinner: false,
      );
    case RideTrackingStatus.expired:
      return const TrackingStatusPresentation(
        title: 'Demande fermee',
        subtitle: 'Cette demande n est plus active.',
        showSpinner: false,
      );
    case RideTrackingStatus.unknown:
      return const TrackingStatusPresentation(
        title: 'Synchronisation du statut',
        subtitle: 'Le suivi revient progressivement a jour.',
        showSpinner: false,
      );
  }
}
