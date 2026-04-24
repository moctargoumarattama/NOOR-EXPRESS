abstract final class RideUiCopy {
  static const refreshing = 'On remet tout a jour...';
  static const reconnecting = 'La connexion revient...';
  static const networkError =
      'La connexion est instable pour le moment. Reessayez dans un instant.';
  static const noDriverAvailable = 'Aucun chauffeur n est disponible pour le moment.';
  static const offerExpired = 'Cette proposition n est plus disponible.';
  static const rideCancelled = 'Le trajet a ete annule.';
  static const driverUnavailable = 'Ce chauffeur n est plus disponible.';
  static const gpsUnavailable =
      'Votre position est difficile a retrouver pour le moment.';
  static const negotiationRefreshHint =
      'Tire vers le bas pour voir les dernieres nouvelles.';
  static const trackingRefreshAction = 'Mettre a jour';

  static String rideCreated(String status) {
    return status.trim().isEmpty
        ? 'Votre demande est partie.'
        : 'Votre demande est partie. $status';
  }
}
