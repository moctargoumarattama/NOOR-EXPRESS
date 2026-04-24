import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/state/session_controller.dart';
import '../widgets/app_snackbar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _rideNotifications = true;
  bool _gpsUpdates = true;
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reglages',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Notifications',
              children: [
                SwitchListTile.adaptive(
                  value: _rideNotifications,
                  onChanged: (value) => _saveBool('ride_notifications', value),
                  title: const Text('Nouvelles courses'),
                  secondary: const Icon(Icons.notifications_rounded),
                ),
                SwitchListTile.adaptive(
                  value: _gpsUpdates,
                  onChanged: (value) => _saveBool('gps_updates', value),
                  title: const Text('Position pendant un trajet'),
                  secondary: const Icon(Icons.location_on_rounded),
                ),
              ],
            ),
            _Section(
              title: 'Langue',
              children: [
                ListTile(
                  onTap: () => AppSnackbar.show(
                    context,
                    message: 'Le francais est deja active.',
                    tone: AppSnackbarTone.info,
                  ),
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('Francais'),
                  subtitle: const Text('Langue actuelle'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            _Section(
              title: 'Application',
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: Text('Version $_version'),
                ),
                ListTile(
                  onTap: _clearCache,
                  leading: const Icon(Icons.cleaning_services_rounded),
                  title: const Text('Effacer les donnees temporaires'),
                ),
              ],
            ),
            _Section(
              title: 'Compte',
              children: [
                ListTile(
                  onTap: _confirmDeleteAccount,
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE53935),
                  ),
                  title: const Text(
                    'Supprimer mon compte',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                  subtitle: const Text(
                    'Cette action vous deconnectera pour le moment.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _rideNotifications = prefs.getBool('ride_notifications') ?? true;
      _gpsUpdates = prefs.getBool('gps_updates') ?? true;
      _version = info.version;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) {
      return;
    }
    setState(() {
      if (key == 'ride_notifications') {
        _rideNotifications = value;
      } else {
        _gpsUpdates = value;
      }
    });
    AppSnackbar.show(
      context,
      message: value ? 'C est enregistre.' : 'C est bien desactive.',
      tone: AppSnackbarTone.success,
    );
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _loadSettings();
    if (!mounted) {
      return;
    }
    AppSnackbar.show(
      context,
      message: 'Les donnees temporaires ont ete effacees.',
      tone: AppSnackbarTone.success,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text(
          'Pour le moment, cette action vous deconnecte simplement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF757575),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
