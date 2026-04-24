import 'package:flutter/material.dart';

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
              icon: Icons.support_agent_rounded,
              title: 'Nous contacter',
              children: [
                'contact@noorexpress.ne',
                '+227 XX XX XX XX',
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
