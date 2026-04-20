import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_text_field.dart';

Future<double?> showPriceProposalSheet(
  BuildContext context, {
  required double initialPrice,
}) async {
  final controller = TextEditingController(
    text: initialPrice.toStringAsFixed(initialPrice == initialPrice.roundToDouble() ? 0 : 2),
  );

  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Proposer un prix', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Ajuste ton offre en FCFA avant de l envoyer.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: controller,
              label: 'Prix proposé',
              hint: '2500',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Valider ce prix',
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
