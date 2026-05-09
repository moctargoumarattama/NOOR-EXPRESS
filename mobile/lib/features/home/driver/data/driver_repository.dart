import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_messages.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import 'models/driver_profile.dart';
import 'models/driver_stats.dart';
import 'models/driver_wallet_summary.dart';

class DriverFailure implements Exception {
  const DriverFailure(this.message);

  final String message;
}

class DriverWalletSnapshot {
  const DriverWalletSnapshot({
    required this.summary,
    required this.platformCommissionPercent,
    required this.commissionDueAmount,
  });

  final DriverWalletSummary summary;
  final double platformCommissionPercent;
  final double commissionDueAmount;
}

class DriverWithdrawalRequest {
  const DriverWithdrawalRequest({
    required this.id,
    required this.amountDue,
    required this.commissionRateSnapshot,
    required this.status,
    required this.createdAt,
    this.driverNote,
    this.adminNote,
    this.confirmedAt,
  });

  final String id;
  final double amountDue;
  final double commissionRateSnapshot;
  final String status;
  final DateTime createdAt;
  final String? driverNote;
  final String? adminNote;
  final DateTime? confirmedAt;

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';

  factory DriverWithdrawalRequest.fromJson(Map<String, dynamic> json) {
    return DriverWithdrawalRequest(
      id: (json['id'] as String?) ?? '',
      amountDue: _asDouble(json['amount_due']),
      commissionRateSnapshot: _asDouble(json['commission_rate_snapshot']),
      status: (json['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      driverNote: json['driver_note'] as String?,
      adminNote: json['admin_note'] as String?,
      confirmedAt: DateTime.tryParse((json['confirmed_at'] as String?) ?? ''),
    );
  }
}

class DriverWithdrawalList {
  const DriverWithdrawalList({
    required this.totalCount,
    required this.items,
    required this.pendingRequest,
  });

  final int totalCount;
  final List<DriverWithdrawalRequest> items;
  final DriverWithdrawalRequest? pendingRequest;
}

class DriverRepository {
  DriverRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DriverProfile> fetchProfile() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/drivers/me/profile',
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverProfileNotFound);
      }

      return DriverProfile.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverProfileLoadFailed,
        ),
      );
    }
  }

  Future<DriverProfile> updateAvailability(bool isAvailable) async {
    return updateStatus(isAvailable ? 'online' : 'offline');
  }

  Future<DriverProfile> updateStatus(String status) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/drivers/me/status',
        data: {'status': status},
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverStatusUpdateFailed);
      }

      return DriverProfile.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverStatusUpdateUnavailable,
        ),
      );
    }
  }

  Future<DriverProfile> updateProfile(DriverProfileUpdateInput input) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/drivers/me/profile',
        data: input.toJson(),
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverProfileUpdateFailed);
      }

      return DriverProfile.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverProfileUpdateUnavailable,
        ),
      );
    }
  }

  Future<DriverProfile> updateMaxRadiusKm(int maxRadiusKm) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/drivers/me/radius',
        data: {'max_radius_km': maxRadiusKm},
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverRadiusUpdateFailed);
      }

      return DriverProfile.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverRadiusUpdateUnavailable,
        ),
      );
    }
  }

  Future<DriverStats> fetchStats() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/drivers/me/stats',
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverStatsNotFound);
      }

      return DriverStats.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverStatsLoadFailed,
        ),
      );
    }
  }

  Future<DriverWalletSummary> fetchWalletSummary() async {
    final snapshot = await fetchWalletSnapshot();
    return snapshot.summary;
  }

  Future<DriverWalletSnapshot> fetchWalletSnapshot() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/drivers/me/wallet',
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverWalletNotFound);
      }
      return DriverWalletSnapshot(
        summary: DriverWalletSummary.fromJson(payload),
        platformCommissionPercent: _asDouble(
          payload['platform_commission_percent'],
        ),
        commissionDueAmount: _asDouble(payload['commission_due_amount']),
      );
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverWalletLoadFailed,
        ),
      );
    }
  }

  Future<DriverWithdrawalList> fetchWithdrawalRequests({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/drivers/me/withdrawal-requests',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverWithdrawalsNotFound);
      }
      final itemsRaw = payload['items'] as List? ?? const [];
      final pendingRaw = payload['pending_request'];
      return DriverWithdrawalList(
        totalCount: (payload['total_count'] as num?)?.toInt() ?? 0,
        items: itemsRaw
            .whereType<Map>()
            .map(
              (item) => DriverWithdrawalRequest.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
        pendingRequest: pendingRaw is Map
            ? DriverWithdrawalRequest.fromJson(
                Map<String, dynamic>.from(pendingRaw),
              )
            : null,
      );
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverWithdrawalsLoadFailed,
        ),
      );
    }
  }

  Future<DriverWithdrawalRequest> createWithdrawalRequest({
    String? driverNote,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/drivers/me/withdrawal-requests',
        data: {'driver_note': driverNote},
      );
      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure(AppMessages.driverWithdrawalCreationFailed);
      }
      return DriverWithdrawalRequest.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverWithdrawalCreationUnavailable,
        ),
      );
    }
  }

  Future<void> cancelWithdrawalRequest(String withdrawalRequestId) async {
    try {
      await _apiClient.dio.delete<void>(
        '/drivers/me/withdrawal-requests/$withdrawalRequestId',
      );
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverWithdrawalCancelUnavailable,
        ),
      );
    }
  }
}

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(apiClient: ref.watch(apiClientProvider));
});

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}
