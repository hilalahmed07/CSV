import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/driver_model.dart';
import '../../models/order_model.dart';
import '../checkout/checkout_page.dart';

class DriverSelectionPage extends StatefulWidget {
  final OrderModel orderData;
  final File scrapImage;

  const DriverSelectionPage({
    Key? key,
    required this.orderData,
    required this.scrapImage,
  }) : super(key: key);

  @override
  State<DriverSelectionPage> createState() => _DriverSelectionPageState();
}

class _DriverSelectionPageState extends State<DriverSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<List<DriverModel>>? _driversStream;

  @override
  void initState() {
    super.initState();
    _driversStream = _firestore
        .collection('drivers')
        .where('isActive', isEqualTo: true)
        .where('state', isEqualTo: widget.orderData.pickupState)
        .where('city', isEqualTo: widget.orderData.pickupCity)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => DriverModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: const Color(0xFFFFD700),
          size: 16,
        );
      }),
    );
  }

  Widget _buildTruckFeature(String feature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        feature,
        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
      ),
    );
  }

  void _onDriverSelected(BuildContext context, DriverModel driver) {
    // These values would typically come from your business logic
    const totalAmount = 50.0;
    const freightCharge = 30.0;
    const pickupFee = 20.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CheckoutPage(
              orderData: widget.orderData,
              selectedDriver: driver,
              scrapImage: widget.scrapImage,
            ),
      ),
    );
  }

  Widget _buildNoDriversFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.car_repair, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No drivers available in your area',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any drivers in ${widget.orderData.pickupCity}, ${widget.orderData.pickupState}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Drivers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<List<DriverModel>>(
        stream: _driversStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final drivers = snapshot.data ?? [];

          if (drivers.isEmpty) {
            return _buildNoDriversFound();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  height: 180,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Driver Image and Rating
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage:
                                  driver.photoUrl != null
                                      ? NetworkImage(driver.photoUrl!)
                                      : null,
                              child:
                                  driver.photoUrl == null
                                      ? const Icon(Icons.person, size: 40)
                                      : null,
                            ),
                            const SizedBox(height: 4),
                            _buildRatingStars(driver.rating),
                            Text(
                              '${driver.rating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Driver Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${driver.city}, ${driver.state}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (driver.truckInfo != null) ...[
                                Text(
                                  'Truck: ${driver.truckInfo!['truckType']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Size: ${driver.truckInfo!['truckSize']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (driver.truckInfo!['hasDolly'] == true)
                                      _buildTruckFeature('Dolly'),
                                    if (driver.truckInfo!['hasLiftgate'] ==
                                        true)
                                      _buildTruckFeature('Liftgate'),
                                    if (driver.truckInfo!['hasPalletJack'] ==
                                        true)
                                      _buildTruckFeature('Pallet Jack'),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Truck Image and Select Button
                        Column(
                          children: [
                            if (driver.truckInfo != null &&
                                driver.truckInfo!.containsKey(
                                  'truckImageURL',
                                ) &&
                                driver.truckInfo!['truckImageURL'] != null &&
                                driver.truckInfo!['truckImageURL']
                                    .toString()
                                    .isNotEmpty)
                              Image.network(
                                driver.truckInfo!['truckImageURL'],
                                height: 80,
                                width: 80,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const SizedBox(),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 80,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () {
                                  _onDriverSelected(context, driver);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
