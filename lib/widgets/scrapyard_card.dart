import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/scrapyard_model.dart';

class ScrapyardCard extends StatelessWidget {
  final ScrapyardModel scrapyard;
  final Position? userPosition;
  final VoidCallback onSelect;

  const ScrapyardCard({
    Key? key,
    required this.scrapyard,
    required this.userPosition,
    required this.onSelect,
  }) : super(key: key);

  double _calculateDistance() {
    if (userPosition == null) return 0;

    try {
      final double scrapyardLat = double.parse(scrapyard.latitude);
      final double scrapyardLng = double.parse(scrapyard.longitude);

      return Geolocator.distanceBetween(
            userPosition!.latitude,
            userPosition!.longitude,
            scrapyardLat,
            scrapyardLng,
          ) /
          1000; // Convert meters to kilometers
    } catch (e) {
      return 0.0; // Return 0 if parsing fails
    }
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: const Color(0xFFFFB800),
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scrapyard.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Open till ${scrapyard.openTill}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${distance.toStringAsFixed(1)} miles away',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Color(0xFF2ECC71),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 50,
                  height: 25,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Select', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${scrapyard.address}, ${scrapyard.state} ${scrapyard.zipCode}',
              style: const TextStyle(fontSize: 14, color: Colors.black),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Rating',
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(width: 8),
                _buildRatingStars(scrapyard.rating),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
