import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lifecycle/app_lifecycle_recovery_service.dart';
import '../core/services/support_contact_service.dart';
import '../core/theme/app_theme.dart';
import 'app_router.dart';

class NoorExpressApp extends ConsumerStatefulWidget {
  const NoorExpressApp({super.key});

  @override
  ConsumerState<NoorExpressApp> createState() => _NoorExpressAppState();
}

class _NoorExpressAppState extends ConsumerState<NoorExpressApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(supportContactServiceProvider).warmupConfig());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      ref
          .read(appLifecycleRecoveryServiceProvider)
          .onLifecycleStateChanged(state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Noor Express',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
