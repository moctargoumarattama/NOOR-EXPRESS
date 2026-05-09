import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/copy/ride_ui_copy.dart';
import '../../../../shared/widgets/app_inline_feedback.dart';
import '../../domain/entities/tracking_state.dart';
import 'eta_chip.dart';

class TrackingTopBar extends StatelessWidget {
  const TrackingTopBar({
    super.key,
    required this.connectionState,
    required this.onBack,
    this.etaMinutes,
    this.distanceRemainingKm,
  });

  final TrackingConnectionState connectionState;
  final int? etaMinutes;
  final double? distanceRemainingKm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.pearl.withValues(alpha: 0.92),
          ),
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (distanceRemainingKm != null)
                  EtaChip(
                      label: '${distanceRemainingKm!.toStringAsFixed(1)} km'),
                if (etaMinutes != null) EtaChip(label: 'Dans $etaMinutes min'),
                ConnectionBadge(connectionState: connectionState),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TrackingSupportButton extends StatelessWidget {
  const TrackingSupportButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.nigerGreen,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(
            Icons.support_agent_rounded,
            color: AppColors.pearl,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({
    super.key,
    required this.connectionState,
  });

  final TrackingConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(connectionState);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        palette.label,
        style: TextStyle(
          color: palette.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  _ConnectionPalette _palette(TrackingConnectionState state) {
    switch (state) {
      case TrackingConnectionState.connected:
        return const _ConnectionPalette(
          label: 'En direct',
          background: AppColors.nigerGreenSoft,
          border: AppColors.nigerGreenBorder,
          foreground: AppColors.nigerGreen,
        );
      case TrackingConnectionState.reconnecting:
        return const _ConnectionPalette(
          label: 'Ca revient',
          background: AppColors.warningSoft,
          border: AppColors.warningBorder,
          foreground: AppColors.warning,
        );
      case TrackingConnectionState.connecting:
        return const _ConnectionPalette(
          label: 'Mise en route',
          background: AppColors.infoSoft,
          border: AppColors.infoBorder,
          foreground: AppColors.info,
        );
      case TrackingConnectionState.disconnected:
        return const _ConnectionPalette(
          label: 'Sans connexion',
          background: AppColors.errorSoft,
          border: AppColors.error,
          foreground: AppColors.error,
        );
    }
  }
}

class TrackingRecoveryBanner extends StatelessWidget {
  const TrackingRecoveryBanner({
    super.key,
    required this.connectionState,
    required this.message,
    required this.onRefresh,
    this.isLoading = false,
  });

  final TrackingConnectionState connectionState;
  final String message;
  final VoidCallback onRefresh;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppInlineFeedback(
      message: message,
      tone: _tone(connectionState),
      isLoading: isLoading,
      actionLabel: RideUiCopy.trackingRefreshAction,
      onAction: onRefresh,
    );
  }

  AppInlineFeedbackTone _tone(TrackingConnectionState state) {
    switch (state) {
      case TrackingConnectionState.disconnected:
        return AppInlineFeedbackTone.error;
      case TrackingConnectionState.reconnecting:
        return AppInlineFeedbackTone.warning;
      case TrackingConnectionState.connecting:
      case TrackingConnectionState.connected:
        return AppInlineFeedbackTone.info;
    }
  }
}

class TrackingEmptyCard extends StatelessWidget {
  const TrackingEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class TrackingErrorCard extends StatelessWidget {
  const TrackingErrorCard({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppInlineFeedback(
      message: message,
      tone: AppInlineFeedbackTone.error,
    );
  }
}

class _ConnectionPalette {
  const _ConnectionPalette({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;
}
