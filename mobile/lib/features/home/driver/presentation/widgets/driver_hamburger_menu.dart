import 'package:flutter/material.dart';

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
            GestureDetector(
              onTap: onClose,
              child: Container(color: Colors.black.withValues(alpha: 0.34)),
            ),
            AnimatedSlide(
              offset: isOpen ? Offset.zero : const Offset(-1, 0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: SafeArea(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 0.82,
                  height: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 24, 18, 22),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DriverMenuHeader(
                        name: driverName,
                        profile: profile,
                        onTap: onProfileTap,
                      ),
                      const SizedBox(height: 22),
                      _StatusSwitch(
                        isOnline: isOnline,
                        isBusy: isUpdatingAvailability,
                        onChanged: onToggleAvailability,
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
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
                              icon: Icons.directions_car_filled_rounded,
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
                              color: const Color(0xFFE96962),
                              onTap: onReportTap,
                            ),
                          ],
                        ),
                      ),
                      _PassengerButton(onTap: onPassengerModeTap),
                      const SizedBox(height: 14),
                      _LogoutButton(onTap: onLogout),
                    ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SwitchListTile.adaptive(
        value: isOnline,
        onChanged: isBusy ? null : onChanged,
        activeThumbColor: const Color(0xFF1B8A5A),
        title: Text(
          isOnline ? 'Disponible' : 'En pause',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        secondary: Icon(
          isOnline ? Icons.radio_button_checked : Icons.pause_circle,
          color: isOnline ? const Color(0xFF1B8A5A) : const Color(0xFFE53935),
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
    this.color = const Color(0xFF1B8A5A),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color == const Color(0xFFE96962)
                      ? color
                      : const Color(0xFF1A1A1A),
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

class _PassengerButton extends StatelessWidget {
  const _PassengerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.person_rounded),
        label: const Text('Passer cote client'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B8A5A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Se deconnecter'),
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
    );
  }
}
