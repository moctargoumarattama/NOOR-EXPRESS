import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_surface_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/ride_tracking_model.dart';
import '../../domain/entities/tracking_state.dart';
import '../controllers/ride_chat_controller.dart';
import '../controllers/tracking_controller.dart';

class RideChatScreen extends ConsumerStatefulWidget {
  const RideChatScreen({
    super.key,
    required this.scope,
    required this.title,
  })  : previewMessages = null,
        previewCurrentUserId = null,
        previewChatAvailable = null;

  const RideChatScreen.preview({
    super.key,
    required this.title,
    required int currentUserId,
    required bool isChatAvailable,
    required List<RideChatMessageModel> messages,
  })  : scope = null,
        previewMessages = messages,
        previewCurrentUserId = currentUserId,
        previewChatAvailable = isChatAvailable;

  final TrackingControllerScope? scope;
  final String title;
  final List<RideChatMessageModel>? previewMessages;
  final int? previewCurrentUserId;
  final bool? previewChatAvailable;

  @override
  ConsumerState<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends ConsumerState<RideChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  ProviderSubscription<TrackingState>? _trackingSubscription;

  bool get _isPreview => widget.scope == null;

  TrackingControllerScope get _scope => widget.scope!;

  @override
  void initState() {
    super.initState();
    if (_isPreview) {
      return;
    }
    _trackingSubscription = ref.listenManual<TrackingState>(
      trackingControllerProvider(_scope),
      (previous, next) {
        final wasAvailable = previous?.ride?.canUseChat ?? true;
        final isAvailable = next.ride?.canUseChat ?? false;
        if (wasAvailable && !isAvailable && mounted) {
          Navigator.of(context).maybePop();
        }
      },
    );
    unawaited(ref.read(rideChatControllerProvider(_scope).notifier).start());
  }

  @override
  void dispose() {
    _trackingSubscription?.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewMessages = widget.previewMessages;
    final previewCurrentUserId = widget.previewCurrentUserId;
    final previewChatAvailable = widget.previewChatAvailable;
    final trackingState =
        _isPreview ? null : ref.watch(trackingControllerProvider(_scope));
    final chatState =
        _isPreview ? null : ref.watch(rideChatControllerProvider(_scope));
    final currentUserId =
        previewCurrentUserId ?? ref.watch(sessionControllerProvider).userId ?? 0;
    final isChatAvailable =
        previewChatAvailable ?? (trackingState?.ride?.canUseChat ?? false);
    final messages = previewMessages ?? chatState?.messages ?? const [];
    final isSending = chatState?.isSending ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            StatusBadge(
              status: isChatAvailable ? 'started' : 'completed',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: isChatAvailable
                    ? _ChatConversation(
                        messages: messages,
                        currentUserId: currentUserId,
                      )
                    : const Center(
                        child: AppSurfaceCard(
                          child: Text(
                            'Le chat n est plus disponible pour cette course.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _ChatComposer(
                controller: _messageController,
                enabled: isChatAvailable && !_isPreview,
                isSending: isSending,
                onSend: () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_isPreview) {
      return;
    }
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      return;
    }
    await ref.read(rideChatControllerProvider(_scope).notifier).sendMessage(
          content,
        );
    if (!mounted) {
      return;
    }
    _messageController.clear();
  }
}

class _ChatConversation extends StatelessWidget {
  const _ChatConversation({
    required this.messages,
    required this.currentUserId,
  });

  final List<RideChatMessageModel> messages;
  final int currentUserId;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: AppSurfaceCard(
          child: Text(
            'Utilisez le chat pour vous retrouver plus facilement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      reverse: false,
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMine = message.isMine(currentUserId);
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            key: Key(
              isMine
                  ? 'chat-message-self-${message.id}'
                  : 'chat-message-peer-${message.id}',
            ),
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: isMine ? AppColors.emerald : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: isMine ? Colors.white : const Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeLabel(message.createdAt),
                      style: TextStyle(
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.84)
                            : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isMine && message.isRead) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Lu',
                        style: TextStyle(
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.96)
                              : AppColors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _timeLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Ecrivez un message utile pour vous retrouver...',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: enabled && !isSending ? onSend : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              minimumSize: const Size(52, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
