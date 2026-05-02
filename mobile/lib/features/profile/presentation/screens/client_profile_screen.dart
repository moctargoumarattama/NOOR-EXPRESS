import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/media/photo_picker_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/client_profile_model.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_ride_history.dart';
import '../widgets/profile_stats_card.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  ConsumerState<ClientProfileScreen> createState() =>
      _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  final _nameController = TextEditingController();
  ProviderSubscription<ProfileState>? _subscription;
  NoorPickedPhoto? _pendingPhoto;
  String _initialFirstName = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _subscription = ref.listenManual<ProfileState>(
      profileControllerProvider,
      (previous, next) {
        final profile = next.profile;
        if (profile != null && previous?.profile != profile) {
          _nameController.text = profile.name ?? '';
          _initialFirstName = (profile.name ?? '').trim();
        }
        final message = next.successMessage ?? next.errorMessage;
        final previousMessage =
            previous?.successMessage ?? previous?.errorMessage;
        if (message != null && message != previousMessage) {
          AppSnackbar.show(
            context,
            message: message,
            tone: next.errorMessage == null
                ? AppSnackbarTone.success
                : AppSnackbarTone.error,
          );
          if (next.successMessage != null) {
            setState(() {
              _pendingPhoto = null;
              _initialFirstName = (next.profile?.name ?? '').trim();
            });
          }
          ref.read(profileControllerProvider.notifier).consumeMessages();
        }
      },
    );
    Future.microtask(() => ref.read(profileControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _subscription?.close();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _pickPhoto() async {
    final selectedSource = await _pickPhotoSource();
    if (selectedSource == null) {
      return;
    }
    try {
      final photo = await ref.read(noorPhotoPickerServiceProvider).pickPhoto(
            source: selectedSource,
            imageQuality: 45,
            maxWidth: 1024,
          );
      if (photo == null) {
        return;
      }
      setState(() => _pendingPhoto = photo);
    } on NoorPhotoPickerFailure catch (error) {
      debugPrint('Client profile photo failed: ${error.message}');
      if (!mounted) {
        return;
      }
      AppSnackbar.show(
        context,
        message: error.message,
        tone: AppSnackbarTone.error,
      );
    } catch (error) {
      debugPrint('Client profile photo upload failed: $error');
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Upload photo impossible. Reessayez.',
          tone: AppSnackbarTone.error,
        );
      }
    }
  }

  Future<NoorPhotoSource?> _pickPhotoSource() {
    return showModalBottomSheet<NoorPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.of(context).pop(NoorPhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Navigator.of(context).pop(NoorPhotoSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasChanges() {
    final currentFirstName = _nameController.text.trim();
    final initialFirstName = _initialFirstName;
    if (currentFirstName != initialFirstName) {
      return true;
    }
    return _pendingPhoto != null;
  }

  Future<void> _save() async {
    final trimmedFirstName = _nameController.text.trim();
    final firstNameToSave =
        trimmedFirstName == _initialFirstName ? null : trimmedFirstName;
    await ref.read(profileControllerProvider.notifier).save(
          firstName: firstNameToSave,
          profilePhoto: _pendingPhoto,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: state.isLoading && profile == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _Header(onBack: context.pop),
                  if (state.errorMessage != null && profile == null)
                    _ErrorState(
                      message: state.errorMessage!,
                      onRetry: () =>
                          ref.read(profileControllerProvider.notifier).load(),
                    )
                  else if (profile != null)
                    _ProfileContent(
                      profile: profile,
                      rides: state.rides,
                      nameController: _nameController,
                      isSaving: state.isSaving,
                      isSaveEnabled: _hasChanges(),
                      pendingPhotoBytes: _pendingPhoto?.bytes,
                      onPickPhoto: _pickPhoto,
                      onSave: _save,
                      onLogout: () {
                        ref.read(sessionControllerProvider.notifier).logout();
                      },
                      onOpenRide: (ride) {
                        context.push(AppRoutes.clientMapWithRide(ride.id));
                      },
                    ),
                ],
              ),
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
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Text(
          'Mon profil',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.rides,
    required this.nameController,
    required this.isSaving,
    required this.isSaveEnabled,
    required this.pendingPhotoBytes,
    required this.onPickPhoto,
    required this.onSave,
    required this.onLogout,
    required this.onOpenRide,
  });

  final ClientProfileModel profile;
  final List<ClientProfileRideModel> rides;
  final TextEditingController nameController;
  final bool isSaving;
  final bool isSaveEnabled;
  final Uint8List? pendingPhotoBytes;
  final VoidCallback onPickPhoto;
  final VoidCallback onSave;
  final VoidCallback onLogout;
  final ValueChanged<ClientProfileRideModel> onOpenRide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        ProfileAvatar(
          initials: profile.initials,
          profilePhoto: profile.profilePhoto,
          localPhotoBytes: pendingPhotoBytes,
          isLoading: isSaving,
          onTap: onPickPhoto,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: isSaving ? null : onPickPhoto,
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(isSaving ? 'Envoi de la photo...' : 'Changer la photo'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.emerald,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: nameController,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: 'Prenom',
            border: InputBorder.none,
          ),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          profile.phoneNumber,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.stone,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            ProfileStatsCard(
              value: profile.totalRides.toString(),
              label: 'courses',
              icon: Icons.route_rounded,
            ),
            const SizedBox(width: 14),
            ProfileStatsCard(
              value: profile.averageRating.toStringAsFixed(1),
              label: 'note',
              icon: Icons.star_rounded,
            ),
          ],
        ),
        const SizedBox(height: 22),
        AppButton(
          label: isSaving ? 'Enregistrement...' : 'Enregistrer',
          onPressed: isSaving || !isSaveEnabled ? null : onSave,
        ),
        const SizedBox(height: 28),
        ProfileRideHistory(rides: rides, onOpenRide: onOpenRide),
        const SizedBox(height: 24),
        AppButton.secondary(
          label: 'Se deconnecter',
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB42318)),
          ),
          const SizedBox(height: 16),
          AppButton.secondary(label: 'Reessayer', onPressed: onRetry),
        ],
      ),
    );
  }
}
