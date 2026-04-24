import 'package:flutter/material.dart';

class HamburgerMenu extends StatelessWidget {
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
  final VoidCallback onReportTap;
  final VoidCallback onDriverModeTap;
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
                child: Container(
                  color: Colors.black.withValues(alpha: 0.34),
                ),
              ),
            ),
            AnimatedSlide(
              offset: isOpen ? Offset.zero : const Offset(-1, 0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: SafeArea(
                child: FractionallySizedBox(
                  widthFactor: 0.82,
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MenuHeader(
                            displayName: displayName,
                            initials: initials,
                            phoneNumber: phoneNumber,
                            onProfileTap: onProfileTap,
                          ),
                          const Divider(height: 30),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _MenuItem(
                                  icon: Icons.history_rounded,
                                  label: 'Mes trajets',
                                  onTap: onHistoryTap,
                                ),
                                _MenuItem(
                                  icon: Icons.notifications_none_rounded,
                                  label: 'Notifications',
                                  onTap: onNotificationsTap,
                                ),
                                _MenuItem(
                                  icon: Icons.person_outline_rounded,
                                  label: 'Mon profil',
                                  onTap: onProfileTap,
                                ),
                                _MenuItem(
                                  icon: Icons.settings_outlined,
                                  label: 'Reglages',
                                  onTap: onSettingsTap,
                                ),
                                _MenuItem(
                                  icon: Icons.help_outline_rounded,
                                  label: 'Aide',
                                  onTap: onHelpTap,
                                ),
                                _MenuItem(
                                  icon: Icons.warning_amber_rounded,
                                  label: 'Parler d un probleme',
                                  color: const Color(0xFFE96962),
                                  onTap: onReportTap,
                                ),
                                const Divider(height: 30),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: onDriverModeTap,
                                    icon: const Icon(Icons.drive_eta_rounded),
                                    label: const Text('Passer cote chauffeur'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B8A5A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.logout_rounded,
                            label: 'Se deconnecter',
                            color: const Color(0xFFE5484D),
                            onTap: onLogout,
                          ),
                        ],
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
    return InkWell(
      onTap: onProfileTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF1B8A5A),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    phoneNumber,
                    style: const TextStyle(color: Color(0xFF757575)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Voir mon profil',
                    style: TextStyle(
                      color: Color(0xFF1B8A5A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF1B8A5A)),
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
    this.color = const Color(0xFF1A1A1A),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: const Color(0xFF1B8A5A).withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
