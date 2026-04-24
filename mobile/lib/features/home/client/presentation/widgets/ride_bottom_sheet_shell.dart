import 'package:flutter/material.dart';

class RideBottomSheetShell extends StatelessWidget {
  const RideBottomSheetShell({
    super.key,
    required this.child,
    this.initialChildSize = 0.34,
    this.minChildSize = 0.22,
    this.maxChildSize = 0.68,
    this.snapSizes,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 26),
  });

  final Widget child;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double>? snapSizes;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        snap: true,
        snapSizes: snapSizes ?? [initialChildSize, maxChildSize],
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: padding,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          );
        },
      ),
    );
  }
}
