import 'package:flutter/material.dart';

class BottomRideSheet extends StatelessWidget {
  const BottomRideSheet({
    super.key,
    required this.child,
    this.primaryAction,
    this.secondaryAction,
  });

  final Widget child;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE1EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              child,
              if (secondaryAction != null || primaryAction != null) ...[
                const SizedBox(height: 20),
                if (secondaryAction != null) secondaryAction!,
                if (secondaryAction != null && primaryAction != null)
                  const SizedBox(height: 12),
                if (primaryAction != null) primaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
