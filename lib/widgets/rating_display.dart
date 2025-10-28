import 'package:flutter/material.dart';

class RatingDisplay extends StatelessWidget {
  final double? rating;
  final double size;
  final Color? color;

  const RatingDisplay({
    Key? key,
    required this.rating,
    this.size = 20,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? const Color(0xFFFFC107); // Default to amber
    final actualRating = rating ?? 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            if (index < actualRating.floor()) {
              // Full star
              return Icon(Icons.star, size: size, color: starColor);
            } else if (index == actualRating.floor() && actualRating % 1 != 0) {
              // Half star
              return Icon(Icons.star_half, size: size, color: starColor);
            } else {
              // Empty star
              return Icon(Icons.star_border, size: size, color: starColor);
            }
          }),
        ),
        const SizedBox(width: 4),
        Text(
          actualRating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
