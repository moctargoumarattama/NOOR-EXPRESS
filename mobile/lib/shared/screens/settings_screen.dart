import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/app_role.dart';
import '../../core/services/support_contact_service.dart';
import '../../core/state/session_controller.dart';
import '../../features/home/driver/presentation/controllers/driver_controller.dart';
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
  int? _driverRadiusKm;
  Timer? _radiusSaveDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSettings);
  }

  @override
  void dispose() {
    _radiusSaveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionControllerProvider);
    final driverState = ref.watch(driverProvider);
    final isDriver = sessionState.role == AppRole.driver;
    final fallbackRadius = driverState.profile?.maxRadiusKm ?? 5;
    final selectedRadiusKm = _driverRadiusKm ?? fallbackRadius;

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
              title: 'Juridique',
              children: [
                ListTile(
                  onTap: _openTermsPage,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('CGU'),
                ),
                ListTile(
                  onTap: _openPrivacyPage,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Politique de confidentialite'),
                ),
              ],
            ),
            if (isDriver)
              _Section(
                title: 'Chauffeur',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rayon de course maximum',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Slider(
                          value: selectedRadiusKm.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$selectedRadiusKm km',
                          onChanged: _onDriverRadiusChanged,
                        ),
                        Text(
                          'Vous recevez les demandes jusqu\'a $selectedRadiusKm km',
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (driverState.isSavingRadius)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Enregistrement...',
                              style: TextStyle(
                                color: Color(0xFF1B8A5A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            _Section(
              title: 'Compte',
              children: [
                ListTile(
                  onTap: sessionState.isBusy ? null : _confirmDeleteAccount,
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFD55A5A),
                  ),
                  title: const Text(
                    'Supprimer mon compte',
                    style: TextStyle(color: Color(0xFFD55A5A)),
                  ),
                  subtitle: const Text(
                    'Action irreversible. Vos donnees personnelles seront anonymisees.',
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
    final sessionState = ref.read(sessionControllerProvider);
    if (sessionState.role == AppRole.driver) {
      await ref.read(driverProvider.notifier).loadProfile();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _rideNotifications = prefs.getBool('ride_notifications') ?? true;
      _gpsUpdates = prefs.getBool('gps_updates') ?? true;
      _version = info.version;
    });
  }

  void _onDriverRadiusChanged(double value) {
    final nextRadius = value.round();
    if (_driverRadiusKm == nextRadius) {
      return;
    }
    setState(() => _driverRadiusKm = nextRadius);
    _scheduleDriverRadiusSave();
  }

  void _scheduleDriverRadiusSave() {
    _radiusSaveDebounce?.cancel();
    _radiusSaveDebounce = Timer(const Duration(seconds: 1), () async {
      final radiusToSave = _driverRadiusKm;
      if (radiusToSave == null) {
        return;
      }

      final persistedRadius = ref.read(driverProvider).profile?.maxRadiusKm;
      if (persistedRadius == radiusToSave) {
        return;
      }

      final error = await ref
          .read(driverProvider.notifier)
          .updateMaxRadiusKm(radiusToSave);
      if (!mounted || error == null) {
        return;
      }
      AppSnackbar.show(
        context,
        message: error,
        tone: AppSnackbarTone.error,
      );
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

  Future<void> _openTermsPage() async {
    await _openLegalLink(
      open: () => ref.read(supportContactServiceProvider).openTermsPage(),
    );
  }

  Future<void> _openPrivacyPage() async {
    await _openLegalLink(
      open: () => ref.read(supportContactServiceProvider).openPrivacyPage(),
    );
  }

  Future<void> _openLegalLink({required Future<bool> Function() open}) async {
    final opened = await open();
    if (!mounted || opened) {
      return;
    }
    AppSnackbar.show(
      context,
      message: 'Impossible d ouvrir le lien legal pour le moment.',
      tone: AppSnackbarTone.error,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmedStepOne = await _showDeleteAccountSummarySheet();
    if (!mounted || confirmedStepOne != true) {
      return;
    }

    final confirmedStepTwo = await _showDeleteAccountWordDialog();
    if (!mounted || confirmedStepTwo != true) {
      return;
    }

    final error =
        await ref.read(sessionControllerProvider.notifier).deleteAccount();
    if (!mounted || error == null) {
      return;
    }
    AppSnackbar.show(
      context,
      message: error,
      tone: AppSnackbarTone.error,
    );
  }

  Future<bool?> _showDeleteAccountSummarySheet() {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: _buildDeleteAccountSummarySheet,
    );
  }

  Future<bool?> _showDeleteAccountWordDialog() async {
    final controller = TextEditingController();
    final canConfirm = ValueNotifier<bool>(false);
    controller.addListener(() {
      canConfirm.value = controller.text.trim().toUpperCase() == 'SUPPRIMER';
    });

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation finale'),
        content: _buildDeleteWordDialogContent(controller),
        actions: _buildDeleteWordDialogActions(context, canConfirm),
      ),
    );
    controller.dispose();
    canConfirm.dispose();
    return confirmed;
  }

  Widget _buildDeleteAccountSummarySheet(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _deleteAccountSummaryChildren(context),
        ),
      ),
    );
  }

  List<Widget> _deleteAccountSummaryChildren(BuildContext context) {
    return [
      const Text(
        'Etes-vous sur ?',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text('La suppression anonymise votre compte et supprime :'),
      const SizedBox(height: 10),
      const Text('- Profil (nom, telephone, photo)'),
      const Text('- Adresses favorites'),
      const Text('- Messages de chat'),
      const Text('- Sessions et tokens actifs'),
      const SizedBox(height: 10),
      const Text(
        'Les courses et signalements restent conserves pour l administration.',
        style: TextStyle(color: Color(0xFF757575), fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      _buildDeleteAccountSummaryActions(context),
    ];
  }

  Widget _buildDeleteAccountSummaryActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD55A5A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuer'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteWordDialogContent(TextEditingController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Saisissez "SUPPRIMER" pour confirmer.'),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'SUPPRIMER',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDeleteWordDialogActions(
    BuildContext context,
    ValueNotifier<bool> canConfirm,
  ) {
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Annuler'),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: canConfirm,
        builder: (context, enabled, _) {
          return TextButton(
            onPressed: enabled ? () => Navigator.of(context).pop(true) : null,
            child: const Text('Supprimer'),
          );
        },
      ),
    ];
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
