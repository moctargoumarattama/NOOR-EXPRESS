import 'package:flutter/material.dart';

import '../../domain/entities/address_result.dart';
import 'address_result_tile.dart';

class RecentAddressesList extends StatelessWidget {
  const RecentAddressesList({
    super.key,
    required this.recents,
    required this.onSelected,
  });

  final List<AddressResult> recents;
  final ValueChanged<AddressResult> onSelected;

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(label: 'Recents'),
        ...recents.map(
          (result) => AddressResultTile(
            key: ValueKey('recent-${result.name}-${result.latitude}'),
            result: result,
            icon: Icons.history_rounded,
            onTap: () => onSelected(result),
          ),
        ),
      ],
    );
  }
}

class AddressSectionTitle extends StatelessWidget {
  const AddressSectionTitle({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => _SectionTitle(label: label);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF8A94A6),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFE8ECF2))),
        ],
      ),
    );
  }
}
