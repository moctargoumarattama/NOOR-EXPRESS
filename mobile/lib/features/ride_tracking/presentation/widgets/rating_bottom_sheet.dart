import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_button.dart';

class RideRatingDraft {
  const RideRatingDraft({
    required this.rating,
    this.comment,
  });

  final int rating;
  final String? comment;
}

Future<RideRatingDraft?> showRideRatingBottomSheet(
  BuildContext context, {
  required String title,
  required String submitLabel,
}) {
  var rating = 5;
  final controller = TextEditingController();

  return showModalBottomSheet<RideRatingDraft>(
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List<Widget>.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => rating = star),
                    icon: Icon(
                      star <= rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: star <= rating
                          ? const Color(0xFFFFB020)
                          : const Color(0xFFBAC3CF),
                      size: 34,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$rating/5',
                style: const TextStyle(
                  color: Color(0xFF5B6575),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 220,
                decoration: const InputDecoration(
                  hintText: 'Commentaire optionnel',
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: submitLabel,
                onPressed: () {
                  Navigator.of(context).pop(
                    RideRatingDraft(
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

Future<RideRatingDraft?> showDriverRatingBottomSheet(
  BuildContext context,
) {
  return showRideRatingBottomSheet(
    context,
    title: 'Noter le chauffeur',
    submitLabel: 'Envoyer la note',
  );
}
