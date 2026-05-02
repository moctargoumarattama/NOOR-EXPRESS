import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/session_controller.dart';
import '../../data/datasources/tracking_remote_datasource.dart';
import '../../data/datasources/tracking_websocket_datasource.dart';
import '../../data/models/ride_tracking_model.dart';
import 'tracking_controller.dart';

class RideChatState {
  const RideChatState({
    required this.messages,
    required this.isLoading,
    required this.isSending,
    required this.hasReachedEnd,
    this.errorMessage,
  });

  const RideChatState.initial()
      : this(
          messages: const [],
          isLoading: false,
          isSending: false,
          hasReachedEnd: false,
        );

  final List<RideChatMessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final bool hasReachedEnd;
  final String? errorMessage;

  RideChatState copyWith({
    List<RideChatMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasReachedEnd,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RideChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RideChatController extends StateNotifier<RideChatState> {
  RideChatController({
    required this.ref,
    required this.scope,
    required TrackingController trackingController,
    required TrackingRemoteDatasource remoteDatasource,
    required TrackingWebSocketDatasource websocketDatasource,
  })  : _remoteDatasource = remoteDatasource,
        _trackingController = trackingController,
        _websocketDatasource = websocketDatasource,
        super(const RideChatState.initial());

  final Ref ref;
  final TrackingControllerScope scope;
  final TrackingRemoteDatasource _remoteDatasource;
  final TrackingController _trackingController;
  final TrackingWebSocketDatasource _websocketDatasource;

  static const _pageSize = 50;

  StreamSubscription<TrackingSocketEvent>? _eventSubscription;
  bool _started = false;
  bool _isDisposed = false;

  Future<void> start() async {
    if (_started || _isDisposed) {
      return;
    }
    _started = true;
    _trackingController.setChatOpen(true);
    _eventSubscription = _websocketDatasource.events.listen(_handleSocketEvent);
    await refresh();
  }

  Future<void> refresh() async {
    if (_isDisposed) {
      return;
    }
    final rideId = _rideId;
    if (rideId == null) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final payload = await _remoteDatasource.fetchRideMessages(
        rideId: rideId,
        limit: _pageSize,
        offset: 0,
      );
      if (_isDisposed) {
        return;
      }
      final page = RideChatPageModel.fromJson(payload);
      _trackingController.syncUnreadChatCount(page.unreadCount);
      state = state.copyWith(
        isLoading: false,
        messages: page.items.reversed.toList(growable: false),
        hasReachedEnd: page.items.length < _pageSize,
      );
    } on TrackingRemoteFailure catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
      );
    }
  }

  Future<void> sendMessage(String content) async {
    if (_isDisposed) {
      return;
    }
    final rideId = _rideId;
    final trimmed = content.trim();
    if (rideId == null || trimmed.isEmpty) {
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);
    try {
      final payload = await _remoteDatasource.sendRideMessage(
        rideId: rideId,
        content: trimmed,
      );
      if (_isDisposed) {
        return;
      }
      final message = RideChatMessageModel.fromJson(payload);
      state = state.copyWith(
        isSending: false,
        messages: _mergeMessages(state.messages, [message]),
      );
    } on TrackingRemoteFailure catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.message,
      );
    }
  }

  void _handleSocketEvent(TrackingSocketEvent event) {
    if (_isDisposed) {
      return;
    }
    if (event.type != TrackingSocketEventType.rideMessage) {
      return;
    }
    final rideId = _rideId;
    final message = event.message;
    if (rideId == null || event.rideId != rideId || message == null) {
      return;
    }
    state = state.copyWith(
      messages: _mergeMessages(state.messages, [message]),
    );
    final currentUserId = ref.read(sessionControllerProvider).userId;
    if (currentUserId != null && !message.isMine(currentUserId)) {
      unawaited(refresh());
    }
  }

  int? get _rideId {
    if (_isDisposed) {
      return null;
    }
    return scope.rideId ?? _trackingController.state.ride?.id;
  }

  List<RideChatMessageModel> _mergeMessages(
    List<RideChatMessageModel> current,
    List<RideChatMessageModel> incoming,
  ) {
    final byId = <int, RideChatMessageModel>{
      for (final message in current) message.id: message,
    };
    for (final message in incoming) {
      byId[message.id] = message;
    }
    final merged = byId.values.toList(growable: false)
      ..sort((left, right) {
        final byDate = left.createdAt.compareTo(right.createdAt);
        if (byDate != 0) {
          return byDate;
        }
        return left.id.compareTo(right.id);
      });
    return merged;
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _trackingController.setChatOpen(false);
      final eventSubscription = _eventSubscription;
      _eventSubscription = null;
      unawaited(eventSubscription?.cancel() ?? Future<void>.value());
    }
    super.dispose();
  }
}

final rideChatControllerProvider = StateNotifierProvider.autoDispose
    .family<RideChatController, RideChatState, TrackingControllerScope>(
  (ref, scope) {
    return RideChatController(
      ref: ref,
      scope: scope,
      trackingController: ref.read(trackingControllerProvider(scope).notifier),
      remoteDatasource: ref.watch(trackingRemoteDatasourceProvider),
      websocketDatasource: ref.watch(
        trackingWebsocketDatasourceProvider(scope.mode),
      ),
    );
  },
);
