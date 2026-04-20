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
          Text('Recents', style: Theme.of(context).textTheme.titleSmall),
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
              labelText: 'Modifier le prix propose',
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
          _PrimaryButton(
            label: isCreating ? 'Creation...' : 'Chercher un driver',
            icon: Icons.local_taxi_rounded,
            onPressed: canSubmit ? onSubmit : null,
            isLoading: isCreating,
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
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Recherche de drivers...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
          'Prix propose : ${ride.estimatedPrice.toStringAsFixed(0)} FCFA',
          style: const TextStyle(
            color: Color(0xFF1B8A5A),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          label: 'Voir les offres',
          icon: Icons.receipt_long_rounded,
          onPressed: onOpen,
        ),
      ],
    );
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
    final text = isLoading
        ? 'Prix suggere : calcul en cours...'
        : error ??
            (estimate == null
                ? 'Prix suggere disponible apres choix des adresses.'
                : 'Prix suggere : ${estimate!.estimatedPrice.round()} FCFA');
    return Text(
      text,
      style: TextStyle(
        color: error == null ? const Color(0xFF1B8A5A) : Colors.red.shade700,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B8A5A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFBFD7CD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
