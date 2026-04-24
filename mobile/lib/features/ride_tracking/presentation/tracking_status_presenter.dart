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
      title: 'Votre trajet',
      subtitle: 'On remet votre trajet a jour.',
      showSpinner: false,
    );
  }

  switch (ride.status) {
    case RideTrackingStatus.pending:
      return const TrackingStatusPresentation(
        title: 'On cherche un chauffeur',
        subtitle: 'Nous prevenons les chauffeurs autour de vous.',
        showSpinner: true,
      );
    case RideTrackingStatus.offered:
      return const TrackingStatusPresentation(
        title: 'Des chauffeurs vous ont repondu',
        subtitle: 'Choisissez la proposition qui vous convient.',
        showSpinner: true,
      );
    case RideTrackingStatus.accepted:
      return const TrackingStatusPresentation(
        title: 'Votre chauffeur arrive',
        subtitle: 'Il se dirige vers votre point de depart.',
        showSpinner: false,
      );
    case RideTrackingStatus.arrived:
      return const TrackingStatusPresentation(
        title: 'Votre chauffeur est sur place',
        subtitle: 'Vous pouvez maintenant le rejoindre.',
        showSpinner: false,
      );
    case RideTrackingStatus.started:
      return TrackingStatusPresentation(
        title: 'Le trajet a commence',
        subtitle: 'Vous allez vers ${ride.dropoffLocation}.',
        showSpinner: false,
      );
    case RideTrackingStatus.completed:
      return const TrackingStatusPresentation(
        title: 'Le trajet est termine',
        subtitle: 'Vous etes bien arrive.',
        showSpinner: false,
      );
    case RideTrackingStatus.cancelled:
      final reason = ride.cancellationReason?.trim();
      return TrackingStatusPresentation(
        title: 'Le trajet a ete annule',
        subtitle: reason == null || reason.isEmpty
            ? 'Ce trajet a ete annule.'
            : 'Raison : $reason',
        showSpinner: false,
      );
    case RideTrackingStatus.expired:
      return const TrackingStatusPresentation(
        title: 'La demande est terminee',
        subtitle:
            'Personne n a repondu a temps. Vous pouvez reessayer quand vous voulez.',
        showSpinner: false,
      );
    case RideTrackingStatus.unknown:
      return const TrackingStatusPresentation(
        title: 'Un instant',
        subtitle: 'Le trajet revient doucement a jour.',
        showSpinner: false,
      );
  }
}

TrackingStatusPresentation buildDriverTrackingStatusPresentation(
  RideTrackingModel? ride,
) {
  if (ride == null) {
    return const TrackingStatusPresentation(
      title: 'Votre trajet',
      subtitle: 'On remet le trajet a jour.',
      showSpinner: false,
    );
  }

  switch (ride.status) {
    case RideTrackingStatus.pending:
    case RideTrackingStatus.offered:
      return const TrackingStatusPresentation(
        title: 'Cette demande attend encore',
        subtitle: 'Le client n a pas encore choisi.',
        showSpinner: true,
      );
    case RideTrackingStatus.accepted:
      return TrackingStatusPresentation(
        title: 'Allez vers le client',
        subtitle: 'Rejoignez ${ride.pickupLocation}.',
        showSpinner: false,
      );
    case RideTrackingStatus.arrived:
      return const TrackingStatusPresentation(
        title: 'Vous etes arrive',
        subtitle: 'Le client peut maintenant vous rejoindre.',
        showSpinner: false,
      );
    case RideTrackingStatus.started:
      return TrackingStatusPresentation(
        title: 'Le trajet a commence',
        subtitle: 'Roulez vers ${ride.dropoffLocation}.',
        showSpinner: false,
      );
    case RideTrackingStatus.completed:
      return const TrackingStatusPresentation(
        title: 'Le trajet est termine',
        subtitle: 'Vous pouvez maintenant revenir a l accueil.',
        showSpinner: false,
      );
    case RideTrackingStatus.cancelled:
      final reason = ride.cancellationReason?.trim();
      return TrackingStatusPresentation(
        title: 'Le trajet a ete annule',
        subtitle: reason == null || reason.isEmpty
            ? 'Ce trajet a ete annule.'
            : 'Raison : $reason',
        showSpinner: false,
      );
    case RideTrackingStatus.expired:
      return const TrackingStatusPresentation(
        title: 'Cette demande est terminee',
        subtitle: 'Elle n est plus active.',
        showSpinner: false,
      );
    case RideTrackingStatus.unknown:
      return const TrackingStatusPresentation(
        title: 'Un instant',
        subtitle: 'Le trajet revient doucement a jour.',
        showSpinner: false,
      );
  }
}
