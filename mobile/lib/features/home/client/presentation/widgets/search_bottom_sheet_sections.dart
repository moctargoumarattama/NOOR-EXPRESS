part of 'search_bottom_sheet.dart';

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.priceController,
    required this.isCreating,
    required this.isEstimatingPrice,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
    required this.onClearDropoff,
    required this.onSubmit,
    this.estimate,
    this.estimateError,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final PriceEstimate? estimate;
  final String? estimateError;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canSubmit = pickup != null && dropoff != null && !isCreating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pickup == null && dropoff == null) ...[
          _SearchLauncher(onTap: onDropoffTap),
          const SizedBox(height: 18),
          Text(
            'Adresses recentes',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          const _RecentAddress(label: 'Grand Marche'),
          const _RecentAddress(label: 'Aeroport Diori Hamani'),
          const _RecentAddress(label: 'Universite Abdou Moumouni'),
        ] else ...[
          AddressInputCard(
            pickup: pickup,
            dropoff: dropoff,
            onPickupTap: onPickupTap,
            onDropoffTap: onDropoffTap,
            onClearPickup: onClearPickup,
            onClearDropoff: onClearDropoff,
          ),
          const SizedBox(height: 14),
          _PriceHint(
            isLoading: isEstimatingPrice,
            estimate: estimate,
            error: estimateError,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Votre prix',
              suffixText: 'FCFA',
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Chercher un chauffeur',
            icon: Icons.local_taxi_rounded,
            isLoading: isCreating,
            onPressed: canSubmit ? onSubmit : null,
          ),
        ],
      ],
    );
  }
}

class _SearchingRidePanel extends StatelessWidget {
  const _SearchingRidePanel({
    super.key,
    required this.ride,
    required this.onOpen,
  });

  final ClientRide ride;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(status: ride.status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${ride.pickupLocation} -> ${ride.dropoffLocation}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Text(
          'Prix choisi : ${ride.displayPrice.toStringAsFixed(0)} FCFA',
          style: const TextStyle(
            color: Color(0xFF1B8A5A),
            fontWeight: FontWeight.w900,
          ),
        ),
        if (_showSpinner) ...[
          const SizedBox(height: 14),
          AppInlineFeedback(
            message: ride.status == 'offered'
                ? 'Des chauffeurs vous ont repondu. Ouvrez la liste pour choisir.'
                : 'On cherche un chauffeur pres de vous.',
            tone: AppInlineFeedbackTone.info,
            isLoading: ride.status == 'pending',
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: _buttonLabel,
          icon: Icons.receipt_long_rounded,
          onPressed: onOpen,
        ),
      ],
    );
  }

  bool get _showSpinner => ride.status == 'pending' || ride.status == 'offered';

  String get _title {
    switch (ride.status) {
      case 'offered':
        return 'Des chauffeurs vous ont repondu';
      case 'accepted':
        return 'Votre chauffeur arrive';
      case 'arrived':
        return 'Votre chauffeur vous attend';
      case 'started':
        return 'Votre trajet est en cours';
      default:
        return 'On cherche un chauffeur';
    }
  }

  String get _buttonLabel {
    switch (ride.status) {
      case 'pending':
      case 'offered':
        return 'Voir les reponses';
      default:
        return 'Voir le trajet';
    }
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF1B8A5A)),
            SizedBox(width: 12),
            Text(
              'Ou allez-vous ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAddress extends StatelessWidget {
  const _RecentAddress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFF757575)),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _PriceHint extends StatelessWidget {
  const _PriceHint({
    required this.isLoading,
    this.estimate,
    this.error,
  });

  final bool isLoading;
  final PriceEstimate? estimate;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AppInlineFeedback(
      message: _message,
      tone: error == null
          ? (estimate == null && !isLoading
              ? AppInlineFeedbackTone.info
              : AppInlineFeedbackTone.success)
          : AppInlineFeedbackTone.error,
      isLoading: isLoading,
    );
  }

  String get _message {
    if (isLoading) {
      return 'On calcule un prix pour vous...';
    }
    if (error != null && error!.trim().isNotEmpty) {
      return error!;
    }
    if (estimate == null) {
      return 'Choisissez vos deux adresses pour voir un prix conseille.';
    }
    return 'Prix conseille : ${estimate!.estimatedPrice.round()} FCFA';
  }
}
