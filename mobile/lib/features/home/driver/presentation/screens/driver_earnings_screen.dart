import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/driver_repository.dart';
import '../../data/models/driver_wallet_summary.dart';
import '../widgets/driver_stats_card.dart';

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() =>
      _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen> {
  late Future<DriverWalletSummary> _walletFuture;

  @override
  void initState() {
    super.initState();
    _walletFuture = ref.read(driverRepositoryProvider).fetchWalletSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mes revenus',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<DriverWalletSummary>(
                future: _walletFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const _DriverEarningsErrorCard();
                  }
                  final wallet = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WindowSection(
                          title: 'Aujourd hui', window: wallet.today),
                      const SizedBox(height: 16),
                      _WindowSection(
                          title: 'Cette semaine', window: wallet.week),
                      const SizedBox(height: 16),
                      _WindowSection(
                          title: 'Depuis inscription', window: wallet.total),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _walletFuture = ref.read(driverRepositoryProvider).fetchWalletSummary();
    });
    await _walletFuture;
  }
}

class _WindowSection extends StatelessWidget {
  const _WindowSection({
    required this.title,
    required this.window,
  });

  final String title;
  final EarningsWindowModel window;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DriverStatsCard(
                label: 'courses',
                value: '${window.ridesCount}',
                icon: Icons.route_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'brut',
                value: '${window.grossAmount.toStringAsFixed(0)} F',
                icon: Icons.payments_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DriverStatsCard(
                label: 'commission',
                value: '${window.commissionAmount.toStringAsFixed(0)} F',
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'net',
                value: '${window.netAmount.toStringAsFixed(0)} F',
                icon: Icons.savings_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DriverEarningsErrorCard extends StatelessWidget {
  const _DriverEarningsErrorCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Impossible de charger les revenus pour le moment.',
        style: TextStyle(color: Color(0xFFE53935)),
      ),
    );
  }
}
