import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/media/photo_picker_service.dart';
import '../../data/driver_repository.dart';
import '../../data/models/driver_profile.dart';
import '../../data/models/driver_stats.dart';
import '../../../../driver_onboarding/data/datasources/driver_profile_datasource.dart';
import '../../../../driver_onboarding/data/models/driver_profile_model.dart';
import '../controllers/driver_controller.dart';
import '../widgets/driver_profile_summary.dart';
import '../widgets/driver_verification_card.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  final _nameController = TextEditingController();
  late Future<DriverStats> _statsFuture;
  late Future<DriverOnboardingProfileModel?> _verificationFuture;
  bool _isPhotoSaving = false;

  @override
  void initState() {
    super.initState();
    _statsFuture = ref.read(driverRepositoryProvider).fetchStats();
    _verificationFuture =
        ref.read(driverProfileDatasourceProvider).fetchProfile();
    Future.microtask(() async {
      await ref.read(driverProvider.notifier).loadProfile();
      _nameController.text = ref.read(driverProvider).profile?.name ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                  DriverIdentityBlock(
                    profile: profile,
                    isPhotoSaving: _isPhotoSaving,
                    onPhotoTap: () => _pickPhoto(profile),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<DriverStats>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const DriverProfileErrorCard(
                          message: 'Statistiques indisponibles.',
                        );
                      }
                      return DriverProfileStatsBlock(stats: snapshot.data);
                    },
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<DriverOnboardingProfileModel?>(
                    future: _verificationFuture,
                    builder: (context, snapshot) {
                      return DriverVerificationCard(profile: snapshot.data);
                    },
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nom',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: state.isSavingProfile ? null : _save,
                      icon: const Icon(Icons.save_rounded),
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
                ],
              ),
      ),
    );
  }

  Future<void> _save() async {
    final profile = ref.read(driverProvider).profile;
    final error = await ref.read(driverProvider.notifier).updateProfile(
          DriverProfileUpdateInput(
            name: _nameController.text.trim(),
            profilePhoto: profile?.profilePhoto,
            vehicleBrand: profile?.vehicleBrand,
            vehicleModel: profile?.vehicleModel,
            vehicleColor: profile?.vehicleColor,
            plateNumber: profile?.plateNumber,
          ),
        );
    _showResult(error, 'Profil mis a jour');
  }

  Future<void> _pickPhoto(DriverProfile? profile) async {
    NoorPickedPhoto? photo;
    try {
      photo = await ref.read(noorPhotoPickerServiceProvider).pickPhoto(
            source: NoorPhotoSource.gallery,
            maxWidth: 256,
            imageQuality: 45,
          );
      if (photo == null) {
        return;
      }
    } on NoorPhotoPickerFailure catch (error) {
      debugPrint('Driver profile photo failed: ${error.message}');
      _showResult(error.message, '');
      return;
    }
    setState(() => _isPhotoSaving = true);
    String? error;
    try {
      error = await ref.read(driverProvider.notifier).updateProfile(
            DriverProfileUpdateInput(
              name: profile?.name,
              profilePhoto: base64Encode(photo.bytes),
              vehicleBrand: profile?.vehicleBrand,
              vehicleModel: profile?.vehicleModel,
              vehicleColor: profile?.vehicleColor,
              plateNumber: profile?.plateNumber,
            ),
          );
    } catch (_) {
      error = 'Upload photo impossible';
    } finally {
      if (mounted) {
        setState(() => _isPhotoSaving = false);
      }
    }
    _showResult(error, 'Photo mise a jour');
  }

  void _showResult(String? error, String success) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? success),
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
          'Mon Profil',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
