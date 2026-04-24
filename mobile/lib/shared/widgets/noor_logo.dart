import 'package:flutter/material.dart';

enum NoorLogoVariant {
  hero,
  header,
  compact,
}

class NoorLogo extends StatelessWidget {
  const NoorLogo({
    super.key,
    this.variant = NoorLogoVariant.header,
    this.width,
  });

  const NoorLogo.hero({
    super.key,
    this.width,
  }) : variant = NoorLogoVariant.hero;

  const NoorLogo.header({
    super.key,
    this.width,
  }) : variant = NoorLogoVariant.header;

  const NoorLogo.compact({
    super.key,
    this.width,
  }) : variant = NoorLogoVariant.compact;

  final NoorLogoVariant variant;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = switch (variant) {
      NoorLogoVariant.hero => width ?? 280,
      NoorLogoVariant.header => width ?? 170,
      NoorLogoVariant.compact => width ?? 120,
    };

    return Semantics(
      label: 'Noor Express logo',
      image: true,
      child: Image.asset(
        'assets/branding/logo.jpeg',
        key: ValueKey('noor-logo-${variant.name}'),
        width: effectiveWidth,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
