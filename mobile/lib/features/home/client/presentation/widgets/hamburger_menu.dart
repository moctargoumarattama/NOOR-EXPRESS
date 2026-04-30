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
                child: Container(
                  color: Colors.black.withValues(alpha: 0.34),
                ),
              ),
            ),
            AnimatedSlide(
              offset: widget.isOpen ? Offset.zero : const Offset(-1, 0),
              duration: const Duration(milliseconds: 250),
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
                        color: AppColors.pearl,
                        clipBehavior: Clip.antiAlias,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MenuHeader(
                                displayName: widget.displayName,
                                initials: widget.initials,
                                phoneNumber: widget.phoneNumber,
                                onProfileTap: widget.onProfileTap,
                              ),
                              const SizedBox(height: 18),
                              Expanded(
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    _MenuItem(
                                      icon: Icons.history_rounded,
                                      label: 'Mes trajets',
                                      onTap: widget.onHistoryTap,
                                    ),
                                    _MenuItem(
                                      icon: Icons.notifications_none_rounded,
                                      label: 'Notifications',
                                      onTap: widget.onNotificationsTap,
                                    ),
                                    _MenuItem(
                                      icon: Icons.person_outline_rounded,
                                      label: 'Mon profil',
                                      onTap: widget.onProfileTap,
                                    ),
                                    _MenuItem(
                                      icon: Icons.settings_outlined,
                                      label: 'Reglages',
                                      onTap: widget.onSettingsTap,
                                    ),
                                    const _MenuDivider(),
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
                                      color: AppColors.coral,
                                      onTap: widget.onReportTap,
                                    ),
                                    const _MenuDivider(),
                                    _MenuItem(
                                      icon: Icons.logout_rounded,
                                      label: 'Se deconnecter',
                                      color: const Color(0xFFE5484D),
                                      onTap: widget.onLogout,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DriverSpaceFooter(onTap: widget.onDriverModeTap),
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

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.displayName,
    required this.initials,
    required this.phoneNumber,
    required this.onProfileTap,
  });

  final String displayName;
  final String initials;
  final String phoneNumber;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final phoneLabel =
        phoneNumber.trim().isEmpty ? 'Telephone non renseigne' : phoneNumber;

    return Material(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onProfileTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.emerald.withValues(alpha: 0.08),
        highlightColor: AppColors.emerald.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.pearl,
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.20),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_iphone_rounded,
                          size: 14,
                          color: AppColors.stone,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            phoneLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.stone),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Voir mon profil',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.emerald,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: AppColors.emerald,
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
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isAccent = color != AppColors.ink;
    final iconColor = isAccent ? color : AppColors.emerald;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.emerald.withValues(alpha: 0.10),
          highlightColor: AppColors.emerald.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
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

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: AppColors.border),
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
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: AppColors.pearl,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Row(
              children: [
                Icon(Icons.drive_eta_rounded, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Espace chauffeur',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Align(
          alignment: Alignment.center,
          child: NoorLogo.compact(width: 82),
        ),
      ],
    );
  }
}
