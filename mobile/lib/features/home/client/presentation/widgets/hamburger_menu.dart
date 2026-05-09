import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/noor_logo.dart';

class HamburgerMenu extends StatefulWidget {
  const HamburgerMenu({
    super.key,
    required this.isOpen,
    required this.displayName,
    required this.initials,
    required this.phoneNumber,
    required this.onClose,
    required this.onProfileTap,
    required this.onHistoryTap,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onHelpTap,
    required this.onSupportTap,
    required this.onPolicyTap,
    required this.onReportTap,
    required this.onDriverModeTap,
    required this.onLogout,
  });

  final bool isOpen;
  final String displayName;
  final String initials;
  final String phoneNumber;
  final VoidCallback onClose;
  final VoidCallback onProfileTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onHelpTap;
  final VoidCallback onSupportTap;
  final VoidCallback onPolicyTap;
  final VoidCallback onReportTap;
  final VoidCallback onDriverModeTap;
  final VoidCallback onLogout;

  @override
  State<HamburgerMenu> createState() => _HamburgerMenuState();
}

class _HamburgerMenuState extends State<HamburgerMenu> {
  static const _closeDragThreshold = 4.0;

  double _leftDragDistance = 0;
  bool _closedFromCurrentDrag = false;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.isOpen,
      child: AnimatedOpacity(
        opacity: widget.isOpen ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('client-menu-overlay'),
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: AppColors.overlay.withValues(alpha: 0.56),
                ),
              ),
            ),
            AnimatedSlide(
              offset: widget.isOpen ? Offset.zero : const Offset(-1, 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.84,
                    heightFactor: 1,
                    child: Listener(
                      key: const ValueKey('client-menu-panel'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _handlePointerDown,
                      onPointerMove: _handlePointerMove,
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
                                _MenuHeader(
                                  displayName: widget.displayName,
                                  initials: widget.initials,
                                  phoneNumber: widget.phoneNumber,
                                  onTap: widget.onProfileTap,
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    children: [
                                      _MenuSection(
                                        title: 'Navigation',
                                        children: [
                                          _MenuItem(
                                            icon: Icons.history_rounded,
                                            label: 'Mes trajets',
                                            onTap: widget.onHistoryTap,
                                          ),
                                          _MenuItem(
                                            icon: Icons
                                                .notifications_none_rounded,
                                            label: 'Notifications',
                                            onTap: widget.onNotificationsTap,
                                          ),
                                          _MenuItem(
                                            icon: Icons.settings_outlined,
                                            label: 'Reglages',
                                            onTap: widget.onSettingsTap,
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
                                            onTap: widget.onHelpTap,
                                          ),
                                          _MenuItem(
                                            icon: Icons.support_agent_rounded,
                                            label: 'Assistance',
                                            onTap: widget.onSupportTap,
                                          ),
                                          _MenuItem(
                                            icon: Icons.privacy_tip_outlined,
                                            label: 'Politique d utilisation',
                                            onTap: widget.onPolicyTap,
                                          ),
                                          _MenuItem(
                                            icon: Icons.report_problem_outlined,
                                            label: 'Signaler un probleme',
                                            color: AppColors.warning,
                                            onTap: widget.onReportTap,
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
                                            onTap: widget.onLogout,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _DriverSpaceFooter(
                                    onTap: widget.onDriverModeTap),
                              ],
                            ),
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

  void _handlePointerDown(PointerDownEvent event) {
    _leftDragDistance = 0;
    _closedFromCurrentDrag = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.isOpen || _closedFromCurrentDrag) {
      return;
    }
    final delta = event.delta.dx;
    if (delta < 0) {
      _leftDragDistance += -delta;
    } else if (delta > 0) {
      final adjustedDistance = _leftDragDistance - delta;
      _leftDragDistance = adjustedDistance < 0 ? 0 : adjustedDistance;
    }
    if (_leftDragDistance >= _closeDragThreshold) {
      _closedFromCurrentDrag = true;
      widget.onClose();
    }
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

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.displayName,
    required this.initials,
    required this.phoneNumber,
    required this.onTap,
  });

  final String displayName;
  final String initials;
  final String phoneNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phoneLabel =
        phoneNumber.trim().isEmpty ? 'Telephone non renseigne' : phoneNumber;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2FBF7),
            Color(0xFFE4F4EC),
          ],
        ),
        border: Border.all(
          color: AppColors.nigerGreenBorder.withValues(alpha: 0.48),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.nigerGreen.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: AppColors.nigerGreen.withValues(alpha: 0.10),
          highlightColor: AppColors.nigerGreen.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF5FBF8),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.nigerGreenBorder,
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.nigerGreen,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.nigerGreenSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Client',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.nigerGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              phoneLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

class _DriverSpaceFooter extends StatelessWidget {
  const _DriverSpaceFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.nigerGreen,
                AppColors.emerald,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.nigerGreen.withValues(alpha: 0.26),
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
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.drive_eta_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Espace chauffeur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
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
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.center,
          child: NoorLogo.compact(width: 74),
        ),
      ],
    );
  }
}
