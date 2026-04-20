import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/otp_input.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  String _code = '';
  int _seconds = 30;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
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
    setState(() => _seconds = 30);
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
          ? AppRoutes.driverOnboardingStatus
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
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () => context.go(AppRoutes.register),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.emerald,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 52, 22, 22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        const _OtpLogo(),
                        const SizedBox(height: 14),
                        Text(
                          'Noor Express',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 26),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.phone_iphone_rounded,
                                color: AppColors.emerald,
                                size: 34,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Verification',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _maskPhone(phoneNumber),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Mode test : utilisez le code 1234',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.stone.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 24),
                              AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_shakeAnimation.value, 0),
                                    child: child,
                                  );
                                },
                                child: OtpInput(
                                    onChanged: (value) => _code = value),
                              ),
                              if (state.errorMessage != null) ...[
                                const SizedBox(height: 18),
                                Text(
                                  state.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      state.isLoading || _code.length != 4
                                          ? null
                                          : _verify,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: state.isLoading
                                        ? const SizedBox(
                                            key: ValueKey('loading'),
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: AppColors.pearl,
                                            ),
                                          )
                                        : const Text(
                                            'Valider et continuer',
                                            key: ValueKey('label'),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _seconds == 0 && !state.isLoading
                                    ? _resend
                                    : null,
                                child: Text(
                                  _seconds == 0
                                      ? 'Renvoyer le code'
                                      : 'Renvoyer dans ${_seconds}s',
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
            ],
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
    return '+227 $prefix XX $tail';
  }
}

class _OtpLogo extends StatelessWidget {
  const _OtpLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.emerald,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_taxi_rounded,
        color: AppColors.pearl,
        size: 30,
      ),
    );
  }
}
