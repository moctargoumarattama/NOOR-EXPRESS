import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _rideAlerts = true;
  bool _offerAlerts = true;
  bool _statusAlerts = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _Header(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 18),
            const _HeroCard(),
            const SizedBox(height: 18),
            _Section(
              title: 'Ce que vous recevez',
              child: Column(
                children: [
                  _NotificationSwitchTile(
                    icon: Icons.local_taxi_rounded,
                    title: 'Trajets et demandes',
                    subtitle:
                        'Nouvelles demandes, annulations et reponses utiles.',
                    value: _rideAlerts,
                    onChanged: (value) => _save('notif_rides', value),
                  ),
                  _NotificationSwitchTile(
                    icon: Icons.price_change_rounded,
                    title: 'Prix et propositions',
                    subtitle: 'Prix proposes et reponses importantes.',
                    value: _offerAlerts,
                    onChanged: (value) => _save('notif_offers', value),
                  ),
                  _NotificationSwitchTile(
                    icon: Icons.route_rounded,
                    title: 'Suivi du trajet',
                    subtitle: 'Arrivee, depart et fin du trajet.',
                    value: _statusAlerts,
                    onChanged: (value) => _save('notif_status', value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _Section(
              title: 'Aujourd hui',
              child: _EmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _rideAlerts = prefs.getBool('notif_rides') ?? true;
      _offerAlerts = prefs.getBool('notif_offers') ?? true;
      _statusAlerts = prefs.getBool('notif_status') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) {
      return;
    }
    setState(() {
      if (key == 'notif_rides') {
        _rideAlerts = value;
      } else if (key == 'notif_offers') {
        _offerAlerts = value;
      } else {
        _statusAlerts = value;
      }
    });
    AppSnackbar.show(
      context,
      message: value ? 'C est bien active.' : 'C est bien desactive.',
      tone: AppSnackbarTone.success,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

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
          'Notifications',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emerald, Color(0xFF12613F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x301B8A5A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.notifications_active_rounded,
              color: AppColors.emerald,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vos nouvelles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Les nouvelles importantes de vos trajets arrivent ici.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.stone,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  const _NotificationSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.emerald,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.emerald),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 26, 20, 28),
      child: Column(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 56,
            color: Color(0xFFB8C2BC),
          ),
          SizedBox(height: 12),
          Text(
            'Aucune notification pour le moment',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Quand quelque chose change sur votre trajet, vous le verrez ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.stone),
          ),
        ],
      ),
    );
  }
}
