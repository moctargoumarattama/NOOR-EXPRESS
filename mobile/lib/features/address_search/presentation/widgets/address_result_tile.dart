import 'package:flutter/material.dart';

import '../../domain/entities/address_result.dart';

class AddressResultTile extends StatefulWidget {
  const AddressResultTile({
    super.key,
    required this.result,
    required this.onTap,
    this.icon = Icons.location_on_rounded,
    this.trailing,
  });

  final AddressResult result;
  final VoidCallback onTap;
  final IconData icon;
  final Widget? trailing;

  @override
  State<AddressResultTile> createState() => _AddressResultTileState();
}

class _AddressResultTileState extends State<AddressResultTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.result.isKnownZone
        ? const Color(0xFF1B8A5A)
        : const Color(0xFF8A94A6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      color: _pressed ? const Color(0xFFEAF3EF) : Colors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            widget.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.result.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.result.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF8A94A6),
                            ),
                      ),
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 12),
                  widget.trailing!,
                ] else ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB5BDCA),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
