import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_role.dart';
import '../../core/services/support_contact_service.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportService = ref.watch(supportContactServiceProvider);
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _Header(
              title: 'Assistance',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 20),
            const _InfoPanel(
              icon: Icons.support_agent_rounded,
              title: 'Assistance Noor Express',
              body: 'Contactez directement notre equipe sur WhatsApp pour '
                  'obtenir une aide rapide.',
            ),
            const SizedBox(height: 14),
            _InfoPanel(
              icon: Icons.mail_outline_rounded,
              title: 'Contact',
              body:
                  'WhatsApp: ${supportService.supportPhone}\nHoraires: ${supportService.supportHours}',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openSupportChat(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: AppColors.pearl,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Contacter le support'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openSupportChat(BuildContext context, WidgetRef ref) async {
  final result = await ref
      .read(supportContactServiceProvider)
      .openSupportChat(AppRole.client);
  if (!context.mounted || result.type != SupportContactResultType.failed) {
    return;
  }
  AppSnackbar.show(
    context,
    message: 'Impossible d ouvrir WhatsApp pour le moment.',
    tone: AppSnackbarTone.error,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
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
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.emerald),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(color: AppColors.stone, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
