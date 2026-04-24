import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';

class PriceSelector extends StatefulWidget {
  const PriceSelector({
    super.key,
    required this.controller,
    this.recommendedPrice,
    this.step = 100,
    this.minPrice = 100,
    this.maxPrice = 500000,
    this.enabled = true,
    this.compact = false,
    this.helperText,
  });

  final TextEditingController controller;
  final double? recommendedPrice;
  final int step;
  final int minPrice;
  final int maxPrice;
  final bool enabled;
  final bool compact;
  final String? helperText;

  @override
  State<PriceSelector> createState() => _PriceSelectorState();
}

class _PriceSelectorState extends State<PriceSelector> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant PriceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _currentValue;
    final hasInvalidInput =
        widget.controller.text.trim().isNotEmpty && value == null;
    final canDecrease = widget.enabled &&
        (value ?? widget.recommendedPrice ?? 0) > widget.minPrice;
    final canIncrease = widget.enabled &&
        (value ?? widget.recommendedPrice ?? 0) < widget.maxPrice;

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8EEE9)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prix propose',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _helperText(hasInvalidInput),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasInvalidInput
                              ? AppColors.coral
                              : AppColors.stone,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value?.toString() ?? '--',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'FCFA',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.emerald,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prix propose',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _helperText(hasInvalidInput),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: hasInvalidInput
                                ? AppColors.coral
                                : AppColors.stone,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              _StepButton(
                key: const ValueKey('price-selector-decrease'),
                icon: Icons.remove_rounded,
                onPressed: canDecrease ? () => _adjust(-widget.step) : null,
              ),
              const SizedBox(width: 8),
              _StepButton(
                key: const ValueKey('price-selector-increase'),
                icon: Icons.add_rounded,
                onPressed: canIncrease ? () => _adjust(widget.step) : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: 'Votre prix',
              suffixText: 'FCFA',
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int? get _currentValue {
    final value = int.tryParse(widget.controller.text.trim());
    if (value == null || value <= 0 || value > widget.maxPrice) {
      return null;
    }
    return value;
  }

  String _helperText(bool hasInvalidInput) {
    if (hasInvalidInput) {
      return 'Entrez un montant valide.';
    }
    final customHelper = widget.helperText;
    if (customHelper != null && customHelper.trim().isNotEmpty) {
      return customHelper;
    }
    final recommended = widget.recommendedPrice;
    if (recommended != null &&
        recommended.isFinite &&
        recommended > 0 &&
        recommended <= widget.maxPrice) {
      return 'Conseil Noor : ${recommended.round()} FCFA';
    }
    return 'Ajustez votre proposition avant de chercher.';
  }

  void _adjust(int delta) {
    final base = _currentValue ?? widget.recommendedPrice?.round() ?? 0;
    final next = (base + delta).clamp(widget.minPrice, widget.maxPrice);
    widget.controller.text = next.toString();
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? const Color(0xFFF1F3F2) : AppColors.mint,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color:
                onPressed == null ? const Color(0xFFADB5AF) : AppColors.emerald,
          ),
        ),
      ),
    );
  }
}
