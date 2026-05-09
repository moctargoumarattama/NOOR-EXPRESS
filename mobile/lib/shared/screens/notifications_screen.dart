import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notification_inbox_service.dart';
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
  bool _isLoadingHistory = true;
  List<NotificationInboxEntry> _history = const <NotificationInboxEntry>[];
  final NotificationInboxService _notificationInboxService =
      NotificationInboxService();

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
            _Section(
              title: 'Dernieres alertes (30 max)',
              child: _HistoryPanel(
                isLoading: _isLoadingHistory,
                entries: _history,
                onRefresh: _loadHistory,
                onClear: _clearHistory,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final history = await _notificationInboxService.fetchRecent(
      limit: NotificationInboxService.maxEntries,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _rideAlerts = prefs.getBool('notif_rides') ?? true;
      _offerAlerts = prefs.getBool('notif_offers') ?? true;
      _statusAlerts = prefs.getBool('notif_status') ?? true;
      _history = history;
      _isLoadingHistory = false;
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

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _notificationInboxService.fetchRecent(
      limit: NotificationInboxService.maxEntries,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _history = history;
      _isLoadingHistory = false;
    });
  }

  Future<void> _clearHistory() async {
    await _notificationInboxService.clear();
    if (!mounted) {
      return;
    }
    setState(() => _history = const <NotificationInboxEntry>[]);
    AppSnackbar.show(
      context,
      message: 'Historique des notifications vide.',
      tone: AppSnackbarTone.info,
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

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.isLoading,
    required this.entries,
    required this.onRefresh,
    required this.onClear,
  });

  final bool isLoading;
  final List<NotificationInboxEntry> entries;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (entries.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 2),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Course acceptee, document valide, avertissement...',
                  style: TextStyle(
                    color: AppColors.stone,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Rafraichir',
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Vider',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final entry in entries) _HistoryTile(entry: entry),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final NotificationInboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForType(entry.type);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tone.softColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(tone.icon, color: tone.iconColor),
      ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            entry.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(entry.receivedAt),
            style: const TextStyle(
              color: AppColors.stone,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _NotificationTone _toneForType(String? type) {
    final value = type?.toLowerCase() ?? '';
    if (value.contains('warning') || value.contains('alert')) {
      return const _NotificationTone(
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.warning,
        softColor: AppColors.warningSoft,
      );
    }
    if (value.contains('document') ||
        value.contains('verification') ||
        value.contains('profile')) {
      return const _NotificationTone(
        icon: Icons.verified_user_rounded,
        iconColor: AppColors.info,
        softColor: AppColors.infoSoft,
      );
    }
    if (value.contains('offer')) {
      return const _NotificationTone(
        icon: Icons.price_change_rounded,
        iconColor: AppColors.gold,
        softColor: Color(0x12F5A623),
      );
    }
    if (value.contains('ride') || value.contains('driver')) {
      return const _NotificationTone(
        icon: Icons.local_taxi_rounded,
        iconColor: AppColors.emerald,
        softColor: AppColors.mint,
      );
    }
    return const _NotificationTone(
      icon: Icons.notifications_rounded,
      iconColor: AppColors.stone,
      softColor: AppColors.border,
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'A l instant';
    }
    if (diff.inHours < 1) {
      return 'Il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours} h';
    }
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month a $hour:$minute';
  }
}

class _NotificationTone {
  const _NotificationTone({
    required this.icon,
    required this.iconColor,
    required this.softColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color softColor;
}
