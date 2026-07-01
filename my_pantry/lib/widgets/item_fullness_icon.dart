import 'package:flutter/material.dart';

class ItemFullnessIcon extends StatelessWidget {
  const ItemFullnessIcon({
    super.key,
    required this.fullnessPercent,
    this.size = 20,
  });

  final int? fullnessPercent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final percent = fullnessPercent;
    if (percent == null) {
      return Icon(Icons.inventory_2_outlined, size: size);
    }

    final clamped = percent.clamp(0, 100);
    final (IconData icon, Color color) = switch (clamped) {
      >= 76 => (Icons.battery_full_rounded, Colors.green),
      >= 41 => (Icons.battery_5_bar_rounded, Colors.orange),
      >= 16 => (Icons.battery_3_bar_rounded, Colors.deepOrange),
      _ => (Icons.battery_1_bar_rounded, Colors.redAccent),
    };

    return Tooltip(
      message: '$clamped% left',
      child: Icon(icon, color: color, size: size),
    );
  }
}
