import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../history/widgets/ride_history_card.dart';
import '../../data/client_rides_repository.dart';
import '../../data/models/client_ride.dart';

class ClientHistoryScreen extends ConsumerStatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  ConsumerState<ClientHistoryScreen> createState() =>
      _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends ConsumerState<ClientHistoryScreen> {
  static const _limit = 20;
  final _rides = <ClientRide>[];
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFirstPage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFirstPage,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: _rides.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(onBack: () => Navigator.of(context).pop());
              }
              if (_rides.isEmpty && !_isLoading && index == 1) {
                return _EmptyState(error: _error);
              }
              if (index <= _rides.length) {
                final ride = _rides[index - 1];
                return RideHistoryCard(
                  key: ValueKey(ride.id),
                  pickup: ride.pickupLocation,
                  dropoff: ride.dropoffLocation,
                  price: ride.displayPrice,
                  status: ride.status,
                  createdAt: ride.createdAt,
                  displayedAt: ride.completedAt,
                  details: [
                    if (ride.clientRatingForDriver != null)
                      'Note donnee: ${ride.clientRatingForDriver!.toStringAsFixed(1)}/5',
                  ],
                  onTap: () => context.push(
                    AppRoutes.rideDetail(ride.id),
                    extra: _rideToJson(ride),
                  ),
                );
              }
              return _LoadMoreFooter(
                isLoading: _isLoading,
                hasMore: _hasMore,
                onLoadMore: _loadMore,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _offset = 0;
      _rides.clear();
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final next = await ref.read(clientRidesRepositoryProvider).fetchMyRides(
            limit: _limit,
            offset: _offset,
          );
      setState(() {
        _rides.addAll(next);
        _offset += _limit;
        _hasMore = next.length == _limit;
        _isLoading = false;
      });
    } on ClientRideFailure catch (error) {
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _rideToJson(ClientRide ride) {
    return {
      'id': ride.id,
      'pickup_location': ride.pickupLocation,
      'dropoff_location': ride.dropoffLocation,
      'estimated_price': ride.estimatedPrice,
      'agreed_price': ride.agreedPrice,
      'final_price': ride.finalPrice,
      'distance_km': ride.distanceKm,
      'duration_minutes': ride.durationMinutes,
      'client_rating_for_driver': ride.clientRatingForDriver,
      'status': ride.status,
      'created_at': ride.createdAt.toIso8601String(),
      'completed_at': ride.completedAt?.toIso8601String(),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          const SizedBox(width: 8),
          const Text(
            'Mes courses',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(error ?? 'Vous n avez encore aucun trajet.'),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
  });

  final bool isLoading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Vous avez tout vu')),
      );
    }
    return TextButton(onPressed: onLoadMore, child: const Text('Voir plus'));
  }
}
