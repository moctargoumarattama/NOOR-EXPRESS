class Messages:
    # Auth
    USER_NOT_FOUND = "Utilisateur introuvable"
    INVALID_CREDENTIALS = "Identifiants incorrects"
    DRIVER_ACCESS_REQUIRED = "Accès réservé aux chauffeurs"
    PASSENGER_ACCESS_REQUIRED = "Accès réservé aux passagers"
    ADMIN_ACCESS_REQUIRED = "Accès réservé aux administrateurs"
    ACCOUNT_SUSPENDED = (
        "Votre compte a été suspendu. "
        "Contactez le support."
    )
    SESSION_EXPIRED = (
        "Votre session a expiré. "
        "Reconnectez-vous."
    )
    AUTHENTICATION_REQUIRED = "Authentification requise"
    INVALID_TOKEN = "Jeton d'authentification invalide"
    TOKEN_EXPIRED = "Session expirée. Reconnectez-vous."
    INVALID_REFRESH_TOKEN = "Jeton de session invalide"
    INVALID_OR_EXPIRED_OTP = "Code OTP invalide ou expiré"
    ACCOUNT_BLOCKED = "Votre compte est bloqué. Contactez le support."
    ACCOUNT_DELETED = "Ce compte n'est plus disponible"
    REGISTER_FIRST = "Utilisateur introuvable. Inscrivez-vous d'abord."
    REGISTER_ROLE_CONFLICT = (
        "Ce numéro est déjà associé à un compte {role_label}. "
        "Connectez-vous avec votre compte existant ou utilisez un autre numéro."
    )
    OTP_SENT = "Code OTP envoyé"
    LOGOUT_SUCCESS = "Déconnexion effectuée"

    # Courses
    RIDE_NOT_FOUND = "Course introuvable"
    RIDE_ALREADY_ACTIVE = (
        "Vous avez déjà une course en cours"
    )
    RIDE_NOT_ACTIVE = "Cette course n'est plus active"
    OFFER_EXPIRED = "Cette offre a expiré"
    OFFER_NOT_FOUND = "Offre introuvable"
    OFFER_ALREADY_EXISTS = "Vous avez déjà répondu à cette course"
    OFFER_ALREADY_RESOLVED = "Cette offre a déjà été traitée"
    RIDE_NOT_NEGOTIABLE = "Cette course n'est plus négociable"
    RIDE_ALREADY_ASSIGNED = "Cette course a déjà une offre gagnante"
    RIDE_NOT_STARTED = "La course n'a pas encore démarré"
    RIDE_TRANSITION_NOT_ALLOWED = "Transition de course non autorisée"
    PRICE_LOCKED = "Le prix de cette course est verrouillé"
    ACCESS_DENIED = "Accès refusé"
    RIDE_CHAT_INACTIVE = "Le chat est disponible uniquement sur une course active"
    RIDE_ACCEPT_DISABLED = (
        "L'acceptation directe est désactivée. "
        "Le chauffeur doit envoyer une offre."
    )
    RIDE_NOT_COMPLETED = "Cette course n'est pas terminée"
    RATING_WINDOW_EXPIRED = "Le délai de notation de cette course a expiré"
    RIDE_RATING_NOT_ALLOWED = "Vous ne pouvez pas noter cette course"
    RIDE_ALREADY_RATED = "Cette course est déjà notée"
    PASSENGER_READY_REQUIRES_ARRIVAL = (
        "Le chauffeur doit être arrivé avant confirmation du passager"
    )

    # Chauffeur
    DRIVER_NOT_VERIFIED = (
        "Votre dossier chauffeur n'est pas "
        "encore validé"
    )
    DRIVER_PROFILE_NOT_FOUND = (
        "Profil chauffeur introuvable"
    )
    DRIVER_NOT_FOUND = "Chauffeur introuvable"
    DRIVER_NOT_ASSIGNED_TO_RIDE = "Ce chauffeur n'est pas assigné à cette course"
    DRIVER_CANNOT_CANCEL_STARTED_RIDE = (
        "Le chauffeur ne peut pas annuler une course déjà démarrée"
    )
    DRIVER_CANCELLATION_NOT_ALLOWED = (
        "Le chauffeur ne peut pas annuler cette course à ce stade"
    )
    VEHICLE_PHOTO_TOO_LARGE = (
        "Photo véhicule trop volumineuse (max 5 MB). "
        "Réessayez avec une image compressée."
    )
    DRIVER_DOCUMENT_STATUS_INVALID = "Le statut du document doit être validé ou rejeté"
    DRIVER_DOCUMENT_REQUIRED_TEMPLATE = "Le document « {label} » est obligatoire"
    DRIVER_DOCUMENT_EXPIRY_REQUIRED_TEMPLATE = (
        "La date d'expiration du document « {label} » est obligatoire"
    )
    DOCUMENT_REJECTION_REASON_REQUIRED = "Le motif de rejet du document est obligatoire"
    DOCUMENT_BASE64_INVALID_TEMPLATE = "Le champ {field_name} doit contenir un base64 valide."
    DOCUMENT_TOO_LARGE_TEMPLATE = (
        "Le champ {field_name} dépasse la limite autorisée ({max_megabytes:.1f} MB)."
    )

    # Wallet
    INSUFFICIENT_BALANCE = (
        "Solde insuffisant — "
        "minimum 500 FCFA requis"
    )
    WITHDRAWAL_ALREADY_PENDING = (
        "Une demande est déjà en attente "
        "de traitement"
    )
    WITHDRAWAL_NOT_FOUND = "Demande de paiement introuvable"
    WITHDRAWAL_PENDING_ONLY = "Action autorisee uniquement sur une demande en attente"
    INVALID_WITHDRAWAL_ACTION = "Action de paiement invalide"
    ADMIN_NOTE_REQUIRED = "La note administrateur est obligatoire"
    NOTE_TOO_LONG = "La note dépasse la longueur autorisée"
    WALLET_DUE_TOO_LOW = "Montant minimum de retrait: 500 FCFA"
    WALLET_DUE_AMOUNT_CONFLICT = (
        "Le montant disponible du wallet est inférieur à la demande"
    )

    # Admin / Simulations
    ADMIN_ALREADY_INITIALIZED = "Un administrateur existe déjà"
    ADMIN_TOKEN_REQUIRED = "Jeton administrateur requis"
    INVALID_ADMIN_TOKEN = "Jeton administrateur invalide"
    INVALID_ADMIN_CREDENTIALS = "Identifiants administrateur incorrects"
    USER_ID_REQUIRED_FOR_TARGET = (
        "Le champ user_id est obligatoire pour cette cible"
    )
    USER_ID_ALLOWED_ONLY_FOR_TARGET = (
        "Le champ user_id est autorise uniquement pour cette cible"
    )
    ADMIN_NOTE_REQUIRED_FOR_REJECT = (
        "Le champ admin_note est obligatoire pour un refus"
    )
    DURATION_REQUIRED_FOR_TEMP_SUSPENSION = (
        "La durée est obligatoire pour une suspension temporaire"
    )
    DURATION_OMITTED_FOR_PERMANENT_SUSPENSION = (
        "La durée doit être omise pour une suspension permanente"
    )
    SUSPENSION_REASON_REQUIRED = "Le motif de suspension est obligatoire"
    SUSPENSION_DURATION_POSITIVE = "La durée de suspension doit être positive"
    BROADCAST_LIMIT_REACHED = "Limite de diffusion atteinte. Reessayez dans quelques secondes."
    BROADCAST_TARGET_UNKNOWN = "Cible de diffusion inconnue"
    DEV_SIMULATIONS_DISABLED = (
        "Les simulations de développement sont désactivées."
    )
    SIMULATION_USER_CREATE_FAILED = "Impossible de créer un utilisateur de simulation"
    SIMULATION_DRIVER_RELOAD_FAILED = "Impossible de recharger le chauffeur de simulation"
    SIMULATION_PRICE_INVALID = "Le prix de simulation est invalide"
    SIMULATION_PRICE_TOO_LOW = "Le prix de simulation est trop bas"
    SIMULATION_RIDE_NOT_FOUND = "Course de simulation introuvable"
    SIMULATION_RIDE_CLIENT_NOT_FOUND = "Client de la course introuvable"
    SIMULATION_RIDE_STATUS_INVALID = (
        "La course doit être en attente ou en négociation"
    )
    SIMULATION_REAL_DRIVER_NEARBY = (
        "Des chauffeurs réels sont proches. Activez allow_real_users=true en développement."
    )

    # Geocoding
    LOCATION_NOT_FOUND = (
        "Position introuvable. "
        "Saisissez l'adresse manuellement."
    )

    # Validation
    FIELD_MUST_BE_STRING_TEMPLATE = "Le champ {field_name} doit être une chaîne de caractères."
    CONTENT_EMPTY = "Le contenu ne peut pas être vide"
    TRACKING_URL_EMPTY = "L'URL de suivi ne peut pas être vide"
    PHONE_NUMBER_EMPTY = "Le numéro de téléphone ne peut pas être vide"
    PHONE_NUMBER_INVALID = "Format de numéro de téléphone invalide"
    LABEL_EMPTY = "Le libellé ne peut pas être vide"
    ADDRESS_DISPLAY_EMPTY = "L'adresse affichée ne peut pas être vide"
    LATITUDE_OUT_OF_RANGE = "La latitude doit être comprise entre -90 et 90"
    LONGITUDE_OUT_OF_RANGE = "La longitude doit être comprise entre -180 et 180"

    # General
    FIELD_REQUIRED = "Ce champ est obligatoire"
    FORBIDDEN = "Action non autorisée"
    NOT_FOUND = "Ressource introuvable"
    SERVER_ERROR = (
        "Une erreur est survenue. "
        "Reessayez dans quelques instants."
    )
    HTTP_ERROR = "Erreur HTTP"
