import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class UsagePolicyScreen extends StatelessWidget {
  const UsagePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _Header(
              title: 'Politique d utilisation',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 20),
            const _PolicyPanel(),
          ],
        ),
      ),
    );
  }
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _PolicyPanel extends StatelessWidget {
  const _PolicyPanel();

  static const _sections = <_PolicySectionData>[
    _PolicySectionData(
      title: '1) Cadre legal local',
      rules: [
        'Tous les utilisateurs doivent respecter les lois en vigueur au Niger.',
        'Toute activite illegale (produits illicites, menace, fraude) est interdite.',
        'Noor Express peut cooperer avec les autorites en cas de signalement grave.',
      ],
    ),
    _PolicySectionData(
      title: '2) Regles pour les clients',
      rules: [
        'Fournir un point de depart reel et une destination claire.',
        'Etre joignable et present au lieu convenu a Niamey.',
        'Respecter le chauffeur et ne pas deteriorer le vehicule.',
        'Valider le prix convenu avant le depart de la course.',
      ],
    ),
    _PolicySectionData(
      title: '3) Regles pour les chauffeurs',
      rules: [
        'Maintenir permis, assurance et documents du vehicule a jour.',
        'Adopter une conduite prudente et respecter le code routier.',
        'Refuser toute course qui met en danger passagers ou circulation.',
        'Eviter les annulations abusives apres acceptation d une course.',
      ],
    ),
    _PolicySectionData(
      title: '4) Securite a Niamey',
      rules: [
        'Privilegier les points de rendez-vous visibles et eclaires.',
        'En trajet de nuit, partager la course avec un proche.',
        'En cas d urgence, contacter d abord les services competents puis le support.',
      ],
    ),
    _PolicySectionData(
      title: '5) Sanctions',
      rules: [
        'Avertissement en cas de non-respect mineur des regles.',
        'Suspension temporaire en cas de recidive ou incident serieux.',
        'Blocage definitif en cas de violence, harcelement ou fraude.',
      ],
    ),
    _PolicySectionData(
      title: '6) Donnees et confidentialite',
      rules: [
        'Les donnees collectees servent au fonctionnement et a la securite du service.',
        'Vous pouvez demander la suppression de votre compte depuis Reglages.',
        'Les historiques necessaires a la conformite peuvent etre conserves legalement.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
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
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.emerald,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ces regles s appliquent a tous les clients et chauffeurs '
                    'sur Noor Express a Niamey. Leur objectif est de garantir '
                    'securite, respect et fiabilite pendant chaque course.',
                    style: TextStyle(color: AppColors.stone, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in _sections) ...[
          _PolicySectionCard(section: section),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Mise a jour: 05/05/2026',
            style: TextStyle(
              color: AppColors.stone,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PolicySectionData {
  const _PolicySectionData({
    required this.title,
    required this.rules,
  });

  final String title;
  final List<String> rules;
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({required this.section});

  final _PolicySectionData section;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final rule in section.rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3, right: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.stone,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rule,
                        style: const TextStyle(
                          color: AppColors.stone,
                          height: 1.4,
                        ),
                      ),
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
