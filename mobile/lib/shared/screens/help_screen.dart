import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Aide',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _HelpCard(
              icon: Icons.help_outline_rounded,
              title: 'Comment ca marche ?',
              children: [
                'Choisissez votre destination',
                'Indiquez le prix qui vous convient',
                'Choisissez un chauffeur',
                'Suivez votre trajet simplement',
              ],
            ),
            const SizedBox(height: 16),
            const _HelpCard(
              icon: Icons.location_on_outlined,
              title: 'Conseils pour Niamey',
              children: [
                'Choisissez un point visible (station, pharmacie, ecole, marche).',
                'Confirmez votre numero pour rester joignable rapidement.',
                'Ecrivez un repere clair: quartier, rond-point ou avenue.',
              ],
            ),
            const SizedBox(height: 16),
            const _HelpCard(
              icon: Icons.shield_outlined,
              title: 'Securite et respect',
              children: [
                'Client et chauffeur doivent rester polis et respectueux.',
                'Aucune menace, insulte ou harcelement n est tolere.',
                'Partagez la course avec un proche en cas de trajet de nuit.',
                'Signalez tout incident depuis "Signaler un probleme".',
              ],
            ),
            const SizedBox(height: 16),
            const _HelpCard(
              icon: Icons.rule_folder_outlined,
              title: 'Bonnes pratiques',
              children: [
                'Ne validez pas une course sans accord sur le prix propose.',
                'Evitez les points isoles et privilegiez les zones eclairees.',
                'Le chauffeur peut refuser une course s il y a un risque securite.',
              ],
            ),
            const SizedBox(height: 16),
            const _HelpCard(
              icon: Icons.support_agent_rounded,
              title: 'Nous contacter',
              children: <String>[
                'contact@noorexpress.ne',
                AppConstants.supportPhone,
                AppConstants.supportHours,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1B8A5A)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          for (final item in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(item, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
