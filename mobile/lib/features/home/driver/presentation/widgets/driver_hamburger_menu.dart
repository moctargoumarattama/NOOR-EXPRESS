import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/noor_logo.dart';
import '../../data/models/driver_profile.dart';
import 'driver_menu_header.dart';

class DriverHamburgerMenu extends StatelessWidget {
  const DriverHamburgerMenu({
    super.key,
    required this.isOpen,
    required this.profile,
    required this.driverName,
    required this.isOnline,
    required this.isUpdatingAvailability,
    required this.onClose,
    required this.onToggleAvailability,
    required this.onProfileTap,
    required this.onStatsTap,
    required this.onEarningsTap,
    required this.onHistoryTap,
    required this.onVehicleTap,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onHelpTap,
    required this.onSupportTap,
    required this.onReportTap,
    required this.onPassengerModeTap,
    required this.onLogout,
  });

  final bool isOpen;
  final DriverProfile? profile;
  final String driverName;
  final bool isOnline;
  final bool isUpdatingAvailability;
  final VoidCallback onClose;
  final ValueChanged<bool> onToggleAvailability;
  final VoidCallback onProfileTap;
  final VoidCallback onStatsTap;
  final VoidCallback onEarningsTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onVehicleTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onHelpTap;
  final VoidCallback onSupportTap;
  final VoidCallback onReportTap;
  final VoidCallback onPassengerModeTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isOpen,
      child: AnimatedOpacity(
        opacity: isOpen ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: AppColors.overlay.withValues(alpha: 0.56),
                ),
              ),
            ),
            AnimatedSlide(
              offset: isOpen ? Offset.zero : const Offset(-1, 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.84,
                    heightFactor: 1,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(32),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xFFF8FBF9),
                            ],
                          ),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(32),
                          ),
                          border: Border.all(
                            color: AppColors.nigerGreenBorder
                                .withValues(alpha: 0.40),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(child: _MenuGrabber()),
                              const SizedBox(height: 8),
                              DriverMenuHeader(
                                name: driverName,
                                profile: profile,
                                onTap: onProfileTap,
                              ),
                              const SizedBox(height: 10),
                              _StatusSwitch(
                                isOnline: isOnline,
                                isBusy: isUpdatingAvailability,
                                onChanged: onToggleAvailability,
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    _MenuSection(
                                      title: 'Navigation',
                                      children: [
                                        _MenuItem(
                                          icon: Icons.query_stats_rounded,
                                          label: 'Mon activite',
                                          onTap: onStatsTap,
                                        ),
                                        _MenuItem(
                                          icon: Icons.payments_rounded,
                                          label: 'Mes revenus',
                                          onTap: onEarningsTap,
                                        ),
                                        _MenuItem(
                                          icon: Icons.history_rounded,
                                          label: 'Mes courses',
                                          onTap: onHistoryTap,
                                        ),
                                        _MenuItem(
                                          icon: Icons
                                              .directions_car_filled_rounded,
                                          label: 'Mon vehicule',
                                          onTap: onVehicleTap,
                                        ),
                                        _MenuItem(
                                          icon: Icons.notifications_rounded,
                                          label: 'Notifications',
                                          onTap: onNotificationsTap,
                                        ),
                                        _MenuItem(
                                          icon: Icons.settings_outlined,
                                          label: 'Reglages',
                                          onTap: onSettingsTap,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _MenuSection(
                                      title: 'Aide et securite',
                                      children: [
                                        _MenuItem(
                                          icon: Icons.help_outline_rounded,
                                          label: 'Aide',
                                          onTap: onHelpTap,
                                        ),
                                        _MenuItem(
                                          icon: Icons.support_agent_rounded,
                                          label: 'Assistance',
                                          onTap: onSupportTap,
                                        ),
                                        _MenuItem(
                                          icon: Icons.warning_amber_rounded,
                                          label: 'Parler d un probleme',
                                          color: AppColors.warning,
                                          onTap: onReportTap,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _MenuSection(
                                      title: 'Compte',
                                      children: [
                                        _MenuItem(
                                          icon: Icons.logout_rounded,
                                          label: 'Se deconnecter',
                                          color: AppColors.error,
                                          isDestructive: true,
                                          onTap: onLogout,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _PassengerButton(onTap: onPassengerModeTap),
                              const SizedBox(height: 8),
                              const Align(
                                alignment: Alignment.center,
                                child: NoorLogo.compact(width: 74),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuGrabber extends StatelessWidget {
  const _MenuGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 3.5,
      decoration: BoxDecoration(
        color: AppColors.nigerGreen.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _StatusSwitch extends StatelessWidget {
  const _StatusSwitch({
    required this.isOnline,
    required this.isBusy,
    required this.onChanged,
  });

  final bool isOnline;
  final bool isBusy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = isOnline ? AppColors.nigerGreen : AppColors.error;
    final soft = isOnline
        ? AppColors.nigerGreenSoft.withValues(alpha: 0.32)
        : AppColors.errorSoft.withValues(alpha: 0.42);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isOnline ? Icons.radio_button_checked : Icons.pause_circle,
                color: accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'Disponible' : 'En pause',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    isOnline
                        ? 'Vous recevez des courses'
                        : 'Les nouvelles courses sont en pause',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isOnline,
              onChanged: isBusy ? null : onChanged,
              activeThumbColor: AppColors.nigerGreen,
              activeTrackColor: AppColors.nigerGreen.withValues(alpha: 0.42),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionChildren = <Widget>[];
    for (final child in children) {
      if (sectionChildren.isNotEmpty) {
        sectionChildren.add(const SizedBox(height: 6));
      }
      sectionChildren.add(child);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pearl.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ...sectionChildren,
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.ink,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDefault = color == AppColors.ink;
    final textColor = isDestructive
        ? AppColors.error
        : (isDefault ? AppColors.textPrimary : color);
    final iconColor = isDestructive
        ? AppColors.error
        : (isDefault ? AppColors.nigerGreen : color);
    final tileColor = isDestructive
        ? AppColors.errorSoft.withValues(alpha: 0.32)
        : Colors.white.withValues(alpha: 0.85);
    final borderColor = isDestructive
        ? AppColors.error.withValues(alpha: 0.22)
        : AppColors.border;

    return Semantics(
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: iconColor.withValues(alpha: 0.10),
            highlightColor: iconColor.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: textColor.withValues(alpha: 0.75),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PassengerButton extends StatelessWidget {
  const _PassengerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.nigerOrange,
            AppColors.gold,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.nigerOrange.withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            width: double.infinity,
            height: 50,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Passer cote client',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
