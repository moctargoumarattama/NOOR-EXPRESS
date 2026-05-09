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
  static const List<int> _quickAdjustments = [-200, -100, 100, 200];
  static const double _fieldHeight = 54;
  static const double _chipSpacing = 8;

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
          color: AppColors.pearl,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
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
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _helperText(hasInvalidInput),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasInvalidInput
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.nigerOrangeSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value?.toString() ?? '--',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.nigerOrangeDark,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'FCFA',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.nigerOrangeDark,
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prix propose',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _fieldHeight,
            child: TextField(
              controller: widget.controller,
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.nigerOrangeDark,
                    fontWeight: FontWeight.w900,
                  ),
              decoration: InputDecoration(
                hintText: widget.recommendedPrice?.round().toString(),
                suffixText: 'FCFA',
                suffixStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w900,
                    ),
                filled: true,
                fillColor: AppColors.nigerOrangeSoft,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: _chipSpacing,
            runSpacing: _chipSpacing,
            children: [
              for (final delta in _quickAdjustments)
                _QuickAdjustmentChip(
                  label: _adjustmentLabel(delta),
                  onTap: _canApplyDelta(delta) ? () => _adjust(delta) : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _helperText(hasInvalidInput),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasInvalidInput
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (canDecrease || canIncrease) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(
                  key: const ValueKey('price-selector-decrease'),
                  icon: Icons.remove_rounded,
                  accentColor: AppColors.nigerOrange,
                  onPressed: canDecrease ? () => _adjust(-widget.step) : null,
                ),
                const SizedBox(width: 10),
                _StepButton(
                  key: const ValueKey('price-selector-increase'),
                  icon: Icons.add_rounded,
                  accentColor: AppColors.nigerOrange,
                  onPressed: canIncrease ? () => _adjust(widget.step) : null,
                ),
              ],
            ),
          ],
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

  String _adjustmentLabel(int delta) {
    final prefix = delta.isNegative ? '' : '+';
    return '$prefix$delta';
  }

  bool _canApplyDelta(int delta) {
    if (!widget.enabled) {
      return false;
    }
    final base = _currentValue ?? widget.recommendedPrice?.round();
    if (base == null) {
      return false;
    }
    return base + delta >= widget.minPrice && base + delta <= widget.maxPrice;
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

class _QuickAdjustmentChip extends StatelessWidget {
  const _QuickAdjustmentChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.backgroundSubtle : AppColors.pearl,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: onTap == null
                  ? AppColors.border
                  : AppColors.nigerOrangeBorder,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onTap == null
                      ? AppColors.textTertiary
                      : AppColors.nigerOrangeDark,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? AppColors.backgroundSubtle : AppColors.pearl,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: onPressed == null
                ? AppColors.border
                : AppColors.nigerOrangeBorder,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              color: onPressed == null ? AppColors.textTertiary : accentColor,
            ),
          ),
        ),
      ),
    );
  }
}
