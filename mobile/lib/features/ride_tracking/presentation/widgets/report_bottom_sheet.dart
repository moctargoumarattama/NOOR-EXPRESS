import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'report_bottom_sheet_states.dart';

class RideReportDraft {
  const RideReportDraft({
    required this.reason,
    this.description,
  });

  final String reason;
  final String? description;
}

Future<RideReportDraft?> showRideReportBottomSheet(
  BuildContext context, {
  Future<void> Function(RideReportDraft draft)? onSubmit,
}) {
  return showModalBottomSheet<RideReportDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReportBottomSheet(onSubmit: onSubmit),
  );
}

class RideReportActionButton extends StatelessWidget {
  const RideReportActionButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.report_problem_rounded),
        label: const Text('Signaler un probleme'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFB42318),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ReportBottomSheet extends StatefulWidget {
  const _ReportBottomSheet({this.onSubmit});

  final Future<void> Function(RideReportDraft draft)? onSubmit;

  @override
  State<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<_ReportBottomSheet> {
  final _descriptionController = TextEditingController();
  String _reason = 'comportement';
  bool _isSubmitting = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE1EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_isSuccess)
              const ReportSuccessState()
            else if (_isSubmitting)
              const ReportLoadingState()
            else ...[
              Text(
                'Signaler un probleme',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              ..._options.map(
                (option) => _ReasonOptionTile(
                  option: option,
                  isSelected: option.value == _reason,
                  onTap: () => setState(() => _reason = option.value),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Description optionnelle',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submit,
                  child: const Text('Envoyer le signalement'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final draft = RideReportDraft(
      reason: _reason,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      Navigator.of(context).pop(draft);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await onSubmit(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop(draft);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l envoi du signalement'),
          backgroundColor: Color(0xFFB42318),
        ),
      );
    }
  }
}

class _ReasonOptionTile extends StatelessWidget {
  const _ReasonOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _ReportOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.emerald : AppColors.border,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: isSelected ? 10 : 0,
                  height: isSelected ? 10 : 0,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(option.label)),
          ],
        ),
      ),
    );
  }
}

class _ReportOption {
  const _ReportOption(this.value, this.label);

  final String value;
  final String label;
}

const _options = [
  _ReportOption('comportement', 'Comportement du driver/client'),
  _ReportOption('prix', 'Desaccord sur le prix'),
  _ReportOption('securite', 'Probleme de securite'),
  _ReportOption('autre', 'Autre'),
];
