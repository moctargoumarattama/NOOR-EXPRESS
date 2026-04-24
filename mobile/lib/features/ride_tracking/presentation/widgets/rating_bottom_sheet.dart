import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_button.dart';

class DriverRatingDraft {
  const DriverRatingDraft({
    required this.rating,
    this.comment,
  });

  final double rating;
  final String? comment;
}

Future<DriverRatingDraft?> showDriverRatingBottomSheet(
  BuildContext context,
) {
  double rating = 5;
  final controller = TextEditingController();

  return showModalBottomSheet<DriverRatingDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => Padding(
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
              const Text(
                'Noter le chauffeur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Slider(
                value: rating,
                min: 1,
                max: 5,
                divisions: 8,
                activeColor: const Color(0xFF1B8A5A),
                onChanged: (value) => setState(() => rating = value),
              ),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Commentaire optionnel',
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Envoyer la note',
                onPressed: () {
                  Navigator.of(context).pop(
                    DriverRatingDraft(
                      rating: rating,
                      comment: controller.text.trim().isEmpty
                          ? null
                          : controller.text.trim(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
