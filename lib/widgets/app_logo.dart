import "package:flutter/material.dart";

import "../kharid_assets.dart";

/// Логотип kharid.tj — `logo1.png`, танҳо баландӣ; андозаи табиӣ, бе кашидан.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fallback = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Image.asset(
      KharidAssets.logo,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          "kharid.tj",
          style: TextStyle(
            fontSize: height * 0.72,
            fontWeight: FontWeight.w900,
            color: fallback,
            letterSpacing: -0.4,
          ),
        );
      },
    );
  }
}
