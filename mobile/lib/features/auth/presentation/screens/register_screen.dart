import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/support_contact_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/noor_logo.dart';
import '../controllers/auth_controller.dart';
import '../widgets/phone_input.dart';
import '../widgets/register_screen_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const double _pagePadding = 20;
  static const double _bottomPanelRadius = 28;
  static const double _bottomPanelPadding = 24;
  static const double _contentGap = 12;
  static const double _majorGap = 20;
  static const double _flagBandHeight = 6;
  static const double _flagBandWidth = 120;
  static const double _footerGap = 20;
  static final RegExp _existingRoleRegex = RegExp(
    r'compte\s+(passager|chauffeur)',
    caseSensitive: false,
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final submittedName = name.isEmpty ? 'Utilisateur Noor' : name;
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _nameError = null;
      _phoneError = phoneDigits.length < 8 ? 'Numero Niger invalide.' : null;
    });
    if (_phoneError != null) {
      return;
    }

    final success =
        await ref.read(authControllerProvider.notifier).registerAndSendOtp(
              name: submittedName,
              phoneNumber: _phoneController.text,
            );
    if (!mounted) {
      return;
    }
    if (!success) {
      await _maybeHandleExistingNumberConflict(
        ref.read(authControllerProvider).errorMessage,
      );
      return;
    }
    context.go(AppRoutes.otp);
  }

  Future<void> _maybeHandleExistingNumberConflict(String? message) async {
    final role = _extractExistingRole(message);
    if (role == null || !mounted) {
      return;
    }

    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Numero deja utilise'),
          content: Text(
            'Ce numero existe deja en tant que $role. '
            'Voulez-vous vous connecter ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Utiliser un autre numero'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Se connecter'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (shouldLogin == true) {
      context.go(AppRoutes.login);
      return;
    }
    if (shouldLogin == false) {
      setState(() {
        _phoneController.clear();
        _phoneError = null;
      });
    }
  }

  String? _extractExistingRole(String? message) {
    if (message == null || message.isEmpty) {
      return null;
    }
    final match = _existingRoleRegex.firstMatch(message.toLowerCase());
    if (match == null) {
      return null;
    }
    final rawRole = match.group(1);
    if (rawRole == null || rawRole.isEmpty) {
      return null;
    }
    return rawRole;
  }

  Future<void> _openTerms() async {
    await _openLegalLink(
      open: () => ref.read(supportContactServiceProvider).openTermsPage(),
    );
  }

  Future<void> _openPrivacy() async {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF4E8),
              AppColors.cloud,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _pagePadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const NoorLogo.hero(width: 230),
                        const SizedBox(height: _contentGap),
                        Container(
                          width: _flagBandWidth,
                          height: _flagBandHeight,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_flagBandHeight),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.gold,
                                AppColors.pearl,
                                AppColors.emerald,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: _majorGap),
                        Text(
                          'Creez votre acces',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: _contentGap),
                        Text(
                          'Simple, rapide et lisible',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    _bottomPanelPadding,
                    _bottomPanelPadding,
                    _bottomPanelPadding,
                    _bottomPanelPadding,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pearl,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_bottomPanelRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Votre nom',
                            hintText: 'Optionnel',
                            prefixIcon: const Icon(Icons.person_rounded),
                            errorText: _nameError,
                          ),
                        ),
                        const SizedBox(height: 16),
                        PhoneInput(
                          controller: _phoneController,
                          errorText: _phoneError,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Je viens en tant que :',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RegisterRoleSelector(selectedRole: state.role),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          RegisterErrorBox(message: state.errorMessage!),
                        ],
                        const SizedBox(height: _majorGap),
                        AppButton(
                          label:
                              state.isLoading ? 'Un instant...' : 'Continuer',
                          onPressed: state.isLoading ? null : _submit,
                        ),
                        const SizedBox(height: _contentGap),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              'En continuant, vous acceptez nos',
                              style: theme.textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed: _openTerms,
                              child: const Text('CGU'),
                            ),
                            Text(
                              'et notre',
                              style: theme.textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed: _openPrivacy,
                              child: const Text('politique de confidentialite'),
                            ),
                          ],
                        ),
                        SizedBox(
                          height:
                              MediaQuery.paddingOf(context).bottom + _footerGap,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(
                              'Niamey, Niger',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.stone,
                              ),
                            ),
                          ),
                        ),
                      ],
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
