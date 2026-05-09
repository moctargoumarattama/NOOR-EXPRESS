import 'dart:async';

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
  static const _historyPageSize = 10;

  DriverWalletSnapshot? _wallet;
  DriverWithdrawalRequest? _pendingRequest;
  List<DriverWithdrawalRequest> _history = const [];
  int _historyTotalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSubmittingRequest = false;
  bool _isCancellingRequest = false;
  String? _errorMessage;

  DriverRepository get _repository => ref.read(driverRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            children: [
              _EarningsHeader(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 20),
              if (_isLoading && _wallet == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_wallet == null)
                _DriverEarningsErrorCard(message: _errorMessage)
              else ...[
                _WalletWindowsSection(wallet: _wallet!),
                const SizedBox(height: 18),
                _CommissionDueSection(
                  wallet: _wallet!,
                  pendingRequest: _pendingRequest,
                  isSubmittingRequest: _isSubmittingRequest,
                  isCancellingRequest: _isCancellingRequest,
                  onCreateRequest: _openCreateRequestSheet,
                  onCancelPending: _cancelPendingRequest,
                ),
                const SizedBox(height: 18),
                _WithdrawalHistorySection(
                  requests: _history,
                  totalCount: _historyTotalCount,
                  isLoadingMore: _isLoadingMore,
                  onLoadMore: _loadMoreHistory,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final wallet = await _repository.fetchWalletSnapshot();
      final withdrawals = await _repository.fetchWithdrawalRequests(
        limit: _historyPageSize,
        offset: 0,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _wallet = wallet;
        _pendingRequest = withdrawals.pendingRequest;
        _history = withdrawals.items;
        _historyTotalCount = withdrawals.totalCount;
      });
    } on DriverFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    await _loadInitialData();
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || _history.length >= _historyTotalCount) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = await _repository.fetchWithdrawalRequests(
        limit: _historyPageSize,
        offset: _history.length,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final merged = List<DriverWithdrawalRequest>.from(_history);
        for (final item in nextPage.items) {
          final exists = merged.any((entry) => entry.id == item.id);
          if (!exists) {
            merged.add(item);
          }
        }
        _history = merged;
        _historyTotalCount = nextPage.totalCount;
        _pendingRequest = nextPage.pendingRequest;
      });
    } on DriverFailure catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _openCreateRequestSheet() async {
    final wallet = _wallet;
    if (wallet == null || _isSubmittingRequest) {
      return;
    }
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _WithdrawalRequestSheet(
        amountDue: wallet.commissionDueAmount,
        commissionPercent: wallet.platformCommissionPercent,
      ),
    );
    if (!mounted || note == null) {
      return;
    }
    await _submitWithdrawalRequest(note);
  }

  Future<void> _submitWithdrawalRequest(String note) async {
    setState(() => _isSubmittingRequest = true);
    try {
      await _repository.createWithdrawalRequest(
        driverNote: note.trim().isEmpty ? null : note.trim(),
      );
      await _reloadWithdrawals();
      _showMessage('Demande envoyee avec succes.');
    } on DriverFailure catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingRequest = false);
      }
    }
  }

  Future<void> _cancelPendingRequest() async {
    final pending = _pendingRequest;
    if (pending == null || _isCancellingRequest) {
      return;
    }
    setState(() => _isCancellingRequest = true);
    try {
      await _repository.cancelWithdrawalRequest(pending.id);
      await _reloadWithdrawals();
      _showMessage('Demande annulee.');
    } on DriverFailure catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isCancellingRequest = false);
      }
    }
  }

  Future<void> _reloadWithdrawals() async {
    final withdrawals = await _repository.fetchWithdrawalRequests(
      limit: _historyPageSize,
      offset: 0,
    );
    final wallet = await _repository.fetchWalletSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _wallet = wallet;
      _pendingRequest = withdrawals.pendingRequest;
      _history = withdrawals.items;
      _historyTotalCount = withdrawals.totalCount;
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _EarningsHeader extends StatelessWidget {
  const _EarningsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        const Text(
          'Mes revenus',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _WalletWindowsSection extends StatelessWidget {
  const _WalletWindowsSection({required this.wallet});

  final DriverWalletSnapshot wallet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WindowSection(title: 'Aujourd hui', window: wallet.summary.today),
        const SizedBox(height: 16),
        _WindowSection(title: 'Cette semaine', window: wallet.summary.week),
        const SizedBox(height: 16),
        _WindowSection(
            title: 'Depuis inscription', window: wallet.summary.total),
      ],
    );
  }
}

class _CommissionDueSection extends StatelessWidget {
  const _CommissionDueSection({
    required this.wallet,
    required this.pendingRequest,
    required this.isSubmittingRequest,
    required this.isCancellingRequest,
    required this.onCreateRequest,
    required this.onCancelPending,
  });

  final DriverWalletSnapshot wallet;
  final DriverWithdrawalRequest? pendingRequest;
  final bool isSubmittingRequest;
  final bool isCancellingRequest;
  final VoidCallback onCreateRequest;
  final VoidCallback onCancelPending;

  @override
  Widget build(BuildContext context) {
    final canCreate =
        wallet.commissionDueAmount >= 500 && pendingRequest == null;
    final isUpToDate = wallet.commissionDueAmount <= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commissions dues',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            'Taux actuel : ${wallet.platformCommissionPercent.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${wallet.commissionDueAmount.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              color: Color(0xFFF57C00),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A regler a Noor Express',
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isUpToDate) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'A jour',
                style: TextStyle(
                  color: Color(0xFF1B8A5A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (pendingRequest != null) ...[
            const SizedBox(height: 14),
            _PendingRequestCard(
              request: pendingRequest!,
              isCancelling: isCancellingRequest,
              onCancel: onCancelPending,
            ),
          ] else if (canCreate) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isSubmittingRequest ? null : onCreateRequest,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B8A5A),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  isSubmittingRequest
                      ? 'Envoi en cours...'
                      : 'Demander une regularisation',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.isCancelling,
    required this.onCancel,
  });

  final DriverWithdrawalRequest request;
  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demande en attente - ${request.amountDue.toStringAsFixed(0)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(request.createdAt),
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isCancelling ? null : onCancel,
              child:
                  Text(isCancelling ? 'Annulation...' : 'Annuler la demande'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalHistorySection extends StatelessWidget {
  const _WithdrawalHistorySection({
    required this.requests,
    required this.totalCount,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<DriverWithdrawalRequest> requests;
  final int totalCount;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final canLoadMore = requests.length < totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique des paiements',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            const Text(
              'Aucune demande pour le moment.',
              style: TextStyle(color: Color(0xFF757575)),
            )
          else
            for (final request in requests) ...[
              _HistoryRequestCard(request: request),
              const SizedBox(height: 10),
            ],
          if (canLoadMore)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isLoadingMore ? null : onLoadMore,
                child: Text(
                  isLoadingMore ? 'Chargement...' : 'Charger plus',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRequestCard extends StatelessWidget {
  const _HistoryRequestCard({required this.request});

  final DriverWithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final badgeColor = request.isConfirmed
        ? const Color(0xFFE8F5E9)
        : request.isRejected
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFFFF8E1);
    final badgeTextColor = request.isConfirmed
        ? const Color(0xFF1B8A5A)
        : request.isRejected
            ? const Color(0xFFE53935)
            : const Color(0xFF8D6E63);
    final statusLabel = request.isConfirmed
        ? 'Confirmee'
        : request.isRejected
            ? 'Refusee'
            : 'En attente';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.amountDue.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(request.createdAt),
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Taux applique : ${request.commissionRateSnapshot.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (request.confirmedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Confirmee le ${_formatDateTime(request.confirmedAt!)}',
              style: const TextStyle(
                color: Color(0xFF1B8A5A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (request.isRejected && request.adminNote != null) ...[
            const SizedBox(height: 4),
            Text(
              'Note admin: ${request.adminNote}',
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WithdrawalRequestSheet extends StatefulWidget {
  const _WithdrawalRequestSheet({
    required this.amountDue,
    required this.commissionPercent,
  });

  final double amountDue;
  final double commissionPercent;

  @override
  State<_WithdrawalRequestSheet> createState() =>
      _WithdrawalRequestSheetState();
}

class _WithdrawalRequestSheetState extends State<_WithdrawalRequestSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demande de regularisation',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.amountDue.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              color: Color(0xFFF57C00),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Commission calculee a ${widget.commissionPercent.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Color(0xFF757575),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ce montant sera paye en cash a l admin.',
            style: TextStyle(
              color: Color(0xFF757575),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLength: 200,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Message (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_noteController.text),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B8A5A),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Envoyer la demande'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ),
        ],
      ),
    );
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
  const _DriverEarningsErrorCard({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message ?? 'Impossible de charger les revenus pour le moment.',
        style: const TextStyle(color: Color(0xFFE53935)),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year.toString();
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
