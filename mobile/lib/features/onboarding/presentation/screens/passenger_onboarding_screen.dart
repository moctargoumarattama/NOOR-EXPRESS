import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/passenger_onboarding_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_surface_card.dart';

class PassengerOnboardingScreen extends ConsumerStatefulWidget {
  const PassengerOnboardingScreen({
    super.key,
    this.onFinishedNavigation,
  });

  final Future<void> Function(BuildContext context)? onFinishedNavigation;

  @override
  ConsumerState<PassengerOnboardingScreen> createState() =>
      _PassengerOnboardingScreenState();
}

class _PassengerOnboardingScreenState
    extends ConsumerState<PassengerOnboardingScreen> {
  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      title: 'Vous proposez, le chauffeur accepte',
      description:
          'Entrez votre destination et proposez le prix que vous souhaitez payer. Les chauffeurs disponibles font leurs offres.',
      icon: Icons.local_offer_outlined,
    ),
    _OnboardingStep(
      title: 'Choisissez votre chauffeur',
      description:
          'Comparez les offres : note, nombre de courses, vehicule. Choisissez celui qui vous convient.',
      icon: Icons.directions_car_filled_outlined,
    ),
    _OnboardingStep(
      title: 'Payez en cash a l arrivee',
      description:
          'Pas de carte bancaire necessaire. Reglez directement le chauffeur au prix negocie.',
      icon: Icons.payments_outlined,
    ),
  ];

  late final PageController _pageController;
  int _currentPage = 0;
  bool _isFinishing = false;

  bool get _isLastPage => _currentPage == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToLastPage() async {
    if (_isLastPage) {
      return;
    }
    await _pageController.animateToPage(
      _steps.length - 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToNextPage() async {
    if (_isLastPage) {
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishing) {
      return;
    }
    setState(() => _isFinishing = true);
    try {
      await ref.read(passengerOnboardingServiceProvider).markCompleted();
      ref.invalidate(passengerOnboardingCompletedProvider);
      if (!mounted) {
        return;
      }
      final onFinishedNavigation = widget.onFinishedNavigation;
      if (onFinishedNavigation != null) {
        await onFinishedNavigation(context);
      } else {
        context.go(AppRoutes.clientHome);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de terminer l onboarding pour le moment.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFinishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7E7C4),
              AppColors.cloud,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildPager(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Comment ca marche ?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: _goToLastPage,
            child: const Text('Passer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPager() {
    return Expanded(
      child: PageView.builder(
        controller: _pageController,
        itemCount: _steps.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          return _OnboardingSlide(step: _steps[index]);
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _OnboardingDots(
            currentIndex: _currentPage,
            count: _steps.length,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: AppButton(
            label: _isLastPage ? 'Commencer' : 'Suivant',
            onPressed: _isLastPage ? _finishOnboarding : _goToNextPage,
            isLoading: _isFinishing,
          ),
        ),
      ],
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: AppSurfaceCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mint,
              ),
              child: Icon(step.icon, size: 42, color: AppColors.emerald),
            ),
            const SizedBox(height: 28),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              step.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingDots extends StatelessWidget {
  const _OnboardingDots({
    required this.currentIndex,
    required this.count,
  });

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: currentIndex == index ? 24 : 9,
            height: 9,
            decoration: BoxDecoration(
              color:
                  currentIndex == index ? AppColors.emerald : AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
