import 'package:flutter/material.dart';

import '../../core/network/api_error.dart';
import '../../core/theme/app_colors.dart';
import 'app_button.dart';

class ConnectivityFallbackView extends StatelessWidget {
  const ConnectivityFallbackView({
    super.key,
    required this.issueType,
    required this.onRetry,
    this.message,
    this.compact = false,
  });

  final ApiIssueType issueType;
  final VoidCallback onRetry;
  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final descriptor = _descriptor(issueType);
    final resolvedMessage = _resolveMessage(descriptor.description);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: descriptor.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: descriptor.softColor,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    descriptor.icon,
                    color: descriptor.iconColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                descriptor.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                resolvedMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.34,
                    ),
              ),
              const SizedBox(height: 16),
              AppButton(label: 'Reessayer', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );

    if (compact) {
      return content;
    }

    return Container(
      color: const Color(0xCCF5F5F5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      alignment: Alignment.center,
      child: content,
    );
  }

  String _resolveMessage(String fallback) {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  _IssueDescriptor _descriptor(ApiIssueType type) {
    switch (type) {
      case ApiIssueType.offline:
        return const _IssueDescriptor(
          title: 'Backend injoignable',
          description:
              'Le serveur Noor Express ne repond pas. Verifiez votre connexion ou l URL du backend puis reessayez.',
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.warning,
          softColor: AppColors.warningSoft,
          borderColor: AppColors.warningBorder,
        );
      case ApiIssueType.timeout:
        return const _IssueDescriptor(
          title: 'Connexion trop lente',
          description:
              'Le delai de reponse est depasse. Reessayez dans quelques secondes.',
          icon: Icons.timer_off_rounded,
          iconColor: AppColors.nigerOrange,
          softColor: AppColors.nigerOrangeSoft,
          borderColor: AppColors.nigerOrangeBorder,
        );
      case ApiIssueType.serverUnavailable:
        return const _IssueDescriptor(
          title: 'Serveur indisponible',
          description:
              'Le service Noor Express est temporairement indisponible.',
          icon: Icons.cloud_off_rounded,
          iconColor: AppColors.error,
          softColor: AppColors.errorSoft,
          borderColor: AppColors.error,
        );
      case ApiIssueType.unknown:
        return const _IssueDescriptor(
          title: 'Connexion impossible',
          description: 'Une erreur de connexion est survenue. Reessayez.',
          icon: Icons.sync_problem_rounded,
          iconColor: AppColors.info,
          softColor: AppColors.infoSoft,
          borderColor: AppColors.infoBorder,
        );
    }
  }
}

class _IssueDescriptor {
  const _IssueDescriptor({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.softColor,
    required this.borderColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color softColor;
  final Color borderColor;
}
