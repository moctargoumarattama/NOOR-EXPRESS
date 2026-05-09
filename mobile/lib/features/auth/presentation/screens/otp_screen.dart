import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/noor_logo.dart';
import '../controllers/auth_controller.dart';
import '../widgets/otp_input.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const double _pagePadding = 20;
  static const double _bottomPanelRadius = 28;
  static const double _bottomPanelPadding = 24;
  static const double _contentGap = 12;
  static const double _majorGap = 20;
  static const double _supportGap = 20;
  static const double _flagBandHeight = 6;
  static const double _flagBandWidth = 120;

  Timer? _timer;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  String _code = '';
  int _seconds = 59;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
        return;
      }
      setState(() => _seconds--);
    });
  }

  Future<void> _verify() async {
    final role =
        await ref.read(authControllerProvider.notifier).verifyOtp(_code);
    if (!mounted || role == null) {
      _shakeController.forward(from: 0);
      return;
    }
    context.go(
      role == AppRole.driver
          ? AppRoutes.driverOnboarding
          : AppRoutes.clientHome,
    );
  }

  Future<void> _resend() async {
    final success = await ref.read(authControllerProvider.notifier).resendOtp();
    if (success && mounted) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final phoneNumber = state.phoneNumber ?? '+227';
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
                          'Code recu ?',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: _contentGap),
                        Text(
                          '${_maskPhone(phoneNumber)} - Verifiez vos SMS',
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
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: OtpInput(onChanged: (value) => _code = value),
                      ),
                      if (state.errorMessage != null) ...[
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
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF9F2D20),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: _majorGap),
                      AppButton(
                        label: state.isLoading ? 'Un instant...' : 'Valider',
                        onPressed: state.isLoading || _code.length != 4
                            ? null
                            : _verify,
                      ),
                      const SizedBox(height: _contentGap),
                      Center(
                        child: TextButton(
                          onPressed: _seconds == 0 && !state.isLoading
                              ? _resend
                              : null,
                          child: Text(
                            _seconds == 0
                                ? 'Renvoyer le code'
                                : 'Renvoyer dans 0:${_seconds.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(height: _contentGap),
                      Center(
                        child: TextButton.icon(
                          onPressed: state.isLoading
                              ? null
                              : () => context.go(AppRoutes.register),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Changer de numero'),
                        ),
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

  String _maskPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      return value;
    }
    final local = digits.startsWith('227') ? digits.substring(3) : digits;
    final prefix = local.length >= 2 ? local.substring(0, 2) : local;
    final tail = digits.substring(digits.length - 4);
    return '+227 $prefix XXX $tail';
  }
}
