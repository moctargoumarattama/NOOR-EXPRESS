abstract final class RideUiCopy {
  static const refreshing = 'On remet tout a jour...';
  static const reconnecting = 'La connexion revient...';
  static const networkError =
      'Le backend Noor Express est inaccessible pour le moment. Verifiez votre connexion ou l URL du serveur.';
  static const noDriverAvailable =
      'Aucun chauffeur n est disponible pour le moment.';
  static const offerExpired = 'Cette proposition n est plus disponible.';
  static const rideCancelled = 'Le trajet a ete annule.';
  static const driverUnavailable = 'Ce chauffeur n est plus disponible.';
  static const activeRideConflict = 'Vous avez deja une course en cours.';
  static const resumeExistingRequest =
      'Vous avez deja une demande en cours. Nous vous y ramenons.';
  static const resumeExistingRide =
      'Vous avez deja une course en cours. Nous vous y ramenons.';
  static const gpsUnavailable =
      'Votre position est difficile a retrouver pour le moment.';
  static const negotiationRefreshHint =
      'Tire vers le bas pour voir les dernieres nouvelles.';
  static const trackingRefreshAction = 'Mettre a jour';
  static const navigateToPickup = 'Aller au passager';
  static const navigateToDestination = 'Aller a destination';
  static const navigationChooserTitle = 'Ouvrir avec...';
  static const pickupNavigationUnavailable =
      'La position du passager est indisponible pour le moment.';
  static const destinationNavigationUnavailable =
      'La destination est indisponible pour le moment.';
  static const navigationOpenFailed =
      'Impossible d ouvrir la navigation pour le moment.';
  static const shareRideAction = 'Partager ma course';
  static const shareRideFallbackCopied =
      'WhatsApp indisponible. Lien copie dans le presse-papiers.';
  static const shareRideFailed =
      'Impossible de partager la course pour le moment.';
  static const shareRideSent = 'Message WhatsApp pret a etre envoye.';
  static const shareRideLinkUnavailable =
      'Le lien de suivi est indisponible pour le moment.';

  static String rideCreated(String status) {
    return status.trim().isEmpty
        ? 'Votre demande est partie.'
        : 'Votre demande est partie. $status';
  }
}
