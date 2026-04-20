import 'package:flutter/material.dart';

class DriverStatsCard extends StatelessWidget {
  const DriverStatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isDark = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101820) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF263442) : const Color(0xFFD2E9DF),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1B8A5A), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark ? Colors.white : const Color(0xFF1B8A5A),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF757575),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
