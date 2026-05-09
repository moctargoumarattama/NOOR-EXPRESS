import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/driver_profile.dart';
import '../controllers/driver_controller.dart';

class DriverVehicleScreen extends ConsumerStatefulWidget {
  const DriverVehicleScreen({super.key});

  @override
  ConsumerState<DriverVehicleScreen> createState() =>
      _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends ConsumerState<DriverVehicleScreen> {
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  bool _isDisposed = false;

  bool get _isUiMounted => mounted && !_isDisposed;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!_isUiMounted) {
        return;
      }
      await ref.read(driverProvider.notifier).loadProfile();
      if (!_isUiMounted) {
        return;
      }
      _fill(ref.read(driverProvider).profile);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverProvider);
    final profile = state.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _Header(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 22),
                  _VehicleCard(profile: profile),
                  const SizedBox(height: 22),
                  const Text(
                    'Modifier',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  _VehicleField(label: 'Marque', controller: _brandController),
                  _VehicleField(label: 'Modele', controller: _modelController),
                  _VehicleField(label: 'Couleur', controller: _colorController),
                  _VehicleField(label: 'Plaque', controller: _plateController),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: state.isSavingProfile ? null : _save,
                      icon: state.isSavingProfile
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B8A5A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Color(0xFFE53935)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  void _fill(DriverProfile? profile) {
    _brandController.text = profile?.vehicleBrand ?? '';
    _modelController.text = profile?.vehicleModel ?? '';
    _colorController.text = profile?.vehicleColor ?? '';
    _plateController.text = profile?.plateNumber ?? '';
  }

  Future<void> _save() async {
    final error = await ref.read(driverProvider.notifier).updateProfile(
          DriverProfileUpdateInput(
            name: ref.read(driverProvider).profile?.name,
            profilePhoto: ref.read(driverProvider).profile?.profilePhoto,
            vehicleBrand: _brandController.text.trim(),
            vehicleModel: _modelController.text.trim(),
            vehicleColor: _colorController.text.trim(),
            plateNumber: _plateController.text.trim(),
          ),
        );
    if (!mounted || !_isUiMounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Vehicule mis a jour'),
        backgroundColor: error == null ? const Color(0xFF1B8A5A) : Colors.red,
      ),
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
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        const Text(
          'Mon vehicule',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.profile});

  final DriverProfile? profile;

  @override
  Widget build(BuildContext context) {
    final title = [
      profile?.vehicleBrand,
      profile?.vehicleModel,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ');
    final subtitle = [
      profile?.vehicleColor,
      profile?.plateNumber,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' - ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_filled, color: Color(0xFF1B8A5A)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Vehicule non renseigne' : title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(subtitle.isEmpty
                    ? 'Couleur et plaque a completer'
                    : subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleField extends StatelessWidget {
  const _VehicleField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
