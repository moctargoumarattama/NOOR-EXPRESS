import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/support_contact_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/noor_logo.dart';
import '../widgets/phone_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const double _pagePadding = 20;
  static const double _bottomPanelRadius = 28;
  static const double _bottomPanelPadding = 24;
  static const double _contentGap = 12;
  static const double _majorGap = 20;
  static const double _supportGap = 20;
  static const double _flagBandHeight = 6;
  static const double _flagBandWidth = 120;

  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawPhone = _phoneController.text.trim().replaceAll(' ', '');
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre ton numero de telephone.')),
      );
      return;
    }
    final phoneNumber = rawPhone.startsWith('+') ? rawPhone : '+227$rawPhone';

    await ref.read(sessionControllerProvider.notifier).login(
          phoneNumber: phoneNumber,
        );
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
    final sessionState = ref.watch(sessionControllerProvider);
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
                          'Bienvenue sur Noor Express',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: _contentGap),
                        Text(
                          'Entrez votre numero pour continuer',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PhoneInput(
                        controller: _phoneController,
                        errorText: null,
                      ),
                      if (sessionState.errorMessage != null) ...[
                        const SizedBox(height: _contentGap),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFD7D2),
                            ),
                          ),
                          child: Text(
                            sessionState.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF9F2D20),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: _majorGap),
                      AppButton(
                        label:
                            sessionState.isBusy ? 'Un instant...' : 'Continuer',
                        onPressed: sessionState.isBusy ? null : _submit,
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
                            MediaQuery.paddingOf(context).bottom + _supportGap,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
