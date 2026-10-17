import 'package:flutter/material.dart';

/// A small "verified seller" badge shown next to a seller's name.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified seller',
      child: Icon(
        Icons.verified,
        size: size,
        color: Colors.amber.shade700,
      ),
    );
  }
}
