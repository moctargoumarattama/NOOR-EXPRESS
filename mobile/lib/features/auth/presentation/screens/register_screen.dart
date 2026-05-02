import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/support_contact_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../controllers/auth_controller.dart';
import '../widgets/phone_input.dart';
import '../widgets/register_screen_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
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
    if (!mounted || !success) {
      return;
    }
    context.go(AppRoutes.otp);
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FFF8), AppColors.pearl],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const RegisterAuthLogo(size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Bienvenue sur Noor Express',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entrez votre numero pour continuer',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.stone,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.pearl,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connexion simple',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Un code OTP confirme votre acces.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Votre nom',
                              hintText: 'Votre nom (optionnel si deja inscrit)',
                              prefixIcon: const Icon(Icons.person_rounded),
                              errorText: _nameError,
                            ),
                          ),
                          const SizedBox(height: 16),
                          PhoneInput(
                            controller: _phoneController,
                            errorText: _phoneError,
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'Deja client ? On vous reconnecte automatiquement.\n'
                              'Nouveau ? On cree votre acces en 30 secondes.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.stone,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Je viens en tant que :',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RegisterRoleSelector(selectedRole: state.role),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Vous pouvez changer plus tard',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.stone,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            RegisterErrorBox(message: state.errorMessage!),
                          ],
                          const SizedBox(height: 22),
                          RegisterPrimaryButton(
                            label: 'Continuer',
                            isLoading: state.isLoading,
                            onPressed: state.isLoading ? null : _submit,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: _openTerms,
                                child: const Text('CGU'),
                              ),
                              const Text('•'),
                              TextButton(
                                onPressed: _openPrivacy,
                                child:
                                    const Text('Politique de confidentialite'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Service de transport urbain a Niamey',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.stone,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
