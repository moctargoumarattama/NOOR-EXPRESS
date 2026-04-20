import 'package:flutter/material.dart';

class CountdownBar extends StatelessWidget {
  const CountdownBar({
    super.key,
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        color: const Color(0xFFFFE3E0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 280),
            curve: Curves.linear,
            widthFactor: progress.clamp(0, 1),
            child: Container(color: const Color(0xFFE53935)),
          ),
        ),
      ),
    );
  }
}
