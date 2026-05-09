class AppMessages {
  const AppMessages._();

  // Erreurs réseau / API (génériques)
  static const apiOffline =
      'Pas de connexion internet. Vérifiez votre réseau puis réessayez.';
  static const apiTimeout =
      'Délai dépassé. La connexion est trop lente pour le moment.';
  static const apiServerUnavailable =
      'Serveur indisponible pour le moment. Réessayez dans un instant.';
  static const apiBadRequest = 'Requête invalide.';
  static const apiUnauthorized = 'Authentification requise.';
  static const apiForbidden = 'Accès refusé.';
  static const apiNotFound = 'Élément introuvable.';

  // Erreurs API (métier)
  static const apiRideAlreadyActive = 'Vous avez déjà une course en cours.';
  static const apiOfferExpired = 'Cette proposition n est plus disponible.';
  static const apiOfferNotFound = 'Offre introuvable.';
  static const apiOfferAlreadyResolved = 'Cette proposition a déjà été traitée.';
  static const apiOfferAlreadyExists = 'Vous avez déjà répondu à cette course.';
  static const apiRideAlreadyAssigned = 'Cette course a déjà une offre acceptée.';
  static const apiRideNotNegotiable = 'Cette course n est plus négociable.';
  static const apiRideTransitionNotAllowed =
      'Cette action n est pas autorisée pour le statut actuel.';
  static const apiPriceLocked = 'Le prix de cette course est déjà verrouillé.';
  static const apiRideAlreadyExpired = 'Cette course a déjà expiré.';
  static const apiRideCancellationNotAllowed =
      'Cette annulation n est pas autorisée pour le moment.';
  static const apiDriverCancelStartedRide =
      'Le chauffeur ne peut pas annuler une course déjà démarrée.';
  static const apiDriverCancellationNotAllowed =
      'Le chauffeur ne peut pas annuler cette course pour le moment.';
  static const apiRideNotFound = 'Course introuvable.';
  static const apiDriverNotFound = 'Chauffeur introuvable.';
  static const apiDriverNotAssignedToRide =
      'Ce chauffeur n est pas assigné à cette course.';
  static const apiRideNotStarted = 'La course n a pas encore commencé.';
  static const apiSessionAnotherDevice =
      'Votre compte est ouvert sur un autre appareil. Reconnectez-vous.';
  static const apiSessionExpired = 'Votre session a expiré. Reconnectez-vous.';
  static const apiPassengerAccessRequired = 'Accès passager requis.';
  static const apiDriverAccessRequired = 'Accès chauffeur requis.';

  // Auth
  static const authTokenMissing = 'Token JWT introuvable.';
  static const authCurrentUserNotFound = 'Utilisateur courant introuvable.';
  static const authUserProfileInvalid = 'Profil utilisateur invalide.';
  static const authSessionExpiredReconnect = 'Session expirée, reconnecte-toi.';
  static const authLoginUnavailable = 'Connexion impossible pour le moment.';
  static const authProfileLoadFailed =
      'Impossible de charger le profil utilisateur.';
  static const authDeleteAccountFailed =
      'Suppression du compte impossible pour le moment.';
  static const authDataTokenInvalid = 'Token de session invalide.';
  static const authRefreshTokenInvalid = 'Refresh token invalide.';
  static const authServiceUnavailable = 'Service auth indisponible.';

  // Client courses
  static const clientRidesLoadFailed = 'Impossible de charger tes courses.';
  static const clientActiveRideCheckFailed =
      'Impossible de vérifier la course active.';
  static const clientRideCreationFailed = 'Création de course impossible.';
  static const clientRideCreationUnavailable =
      'Création de course impossible pour le moment.';
  static const clientPriceEstimateFailed = 'Estimation du prix impossible.';
  static const clientPriceEstimateUnavailable =
      'Estimation du prix impossible pour le moment.';

  // Chauffeur
  static const driverProfileNotFound = 'Profil chauffeur introuvable.';
  static const driverProfileLoadFailed =
      'Impossible de charger le profil chauffeur.';
  static const driverStatusUpdateFailed = 'Mise à jour du statut impossible.';
  static const driverStatusUpdateUnavailable =
      'Impossible de mettre à jour le statut chauffeur.';
  static const driverProfileUpdateFailed = 'Mise à jour du profil impossible.';
  static const driverProfileUpdateUnavailable =
      'Impossible de mettre à jour le profil chauffeur.';
  static const driverRadiusUpdateFailed = 'Mise à jour du rayon impossible.';
  static const driverRadiusUpdateUnavailable =
      'Impossible de mettre à jour le rayon chauffeur.';
  static const driverStatsNotFound = 'Statistiques chauffeur introuvables.';
  static const driverStatsLoadFailed =
      'Impossible de charger les statistiques chauffeur.';
  static const driverWalletNotFound = 'Wallet chauffeur introuvable.';
  static const driverWalletLoadFailed =
      'Impossible de charger les revenus chauffeur.';
  static const driverWithdrawalsNotFound =
      'Demandes de régularisation introuvables.';
  static const driverWithdrawalsLoadFailed =
      'Impossible de charger les demandes de régularisation.';
  static const driverWithdrawalCreationFailed =
      'Création de la demande impossible.';
  static const driverWithdrawalCreationUnavailable =
      'Impossible d envoyer la demande de régularisation.';
  static const driverWithdrawalCancelUnavailable =
      'Impossible d annuler la demande de régularisation.';

  // Chauffeur - courses
  static const driverRidesAvailableLoadFailed =
      'Impossible de charger les demandes disponibles.';
  static const driverRidesLoadFailed = 'Impossible de charger les courses chauffeur.';
  static const driverActiveRideLoadFailed =
      'Impossible de charger la course active.';
  static const driverRideRejectFailed = 'Refus impossible.';
  static const driverRideRejectUnavailable =
      'Impossible de refuser cette course.';

  // Tracking
  static const trackingRidesLoadFailed = 'Impossible de charger vos trajets.';
  static const trackingRideInfoLoadFailed =
      'Impossible de charger les informations du trajet.';
  static const trackingActionUnavailable =
      'Cette action n est pas disponible pour le moment.';

  // Carte
  static const mapLiveDriversLoadFailed =
      'Impossible de charger les chauffeurs en direct.';
  static const mapNearbyDriversLoadFailed =
      'Impossible de charger les chauffeurs proches.';
}
