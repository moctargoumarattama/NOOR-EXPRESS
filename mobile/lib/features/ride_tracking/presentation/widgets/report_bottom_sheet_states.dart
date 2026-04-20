import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ReportLoadingState extends StatelessWidget {
  const ReportLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: Color(0xFFB42318)),
            SizedBox(height: 14),
            Text('Envoi en cours...'),
          ],
        ),
      ),
    );
  }
}

class ReportSuccessState extends StatelessWidget {
  const ReportSuccessState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.emerald,
              size: 54,
            ),
            SizedBox(height: 12),
            Text(
              'Signalement envoye',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
