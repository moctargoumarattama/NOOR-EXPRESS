import 'package:flutter/material.dart';

class RecenterMapButton extends StatelessWidget {
  const RecenterMapButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          width: 54,
          height: 54,
          child: Icon(Icons.my_location_rounded, color: Color(0xFF1B8A5A)),
        ),
      ),
    );
  }
}
