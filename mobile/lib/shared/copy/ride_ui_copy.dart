abstract final class RideUiCopy {
  static const refreshing = 'Mise a jour en cours...';
  static const reconnecting = 'Reconnexion en cours...';
  static const networkError =
      'Connexion instable. Reessayez dans quelques instants.';
  static const noDriverAvailable = 'Aucun chauffeur disponible pour le moment.';
  static const offerExpired = 'Cette offre n est plus disponible.';
  static const rideCancelled = 'La course a ete annulee.';
  static const driverUnavailable = 'Ce chauffeur n est plus disponible.';
  static const gpsUnavailable =
      'Position GPS indisponible. Reessayez dans un endroit mieux couvert.';
  static const negotiationRefreshHint =
      'Tire vers le bas pour resynchroniser avec le backend si les offres tardent.';
  static const trackingRefreshAction = 'Rafraichir l etat';

  static String rideCreated(String status) {
    return status.trim().isEmpty
        ? 'Demande envoyee.'
        : 'Demande envoyee. $status';
  }
}
