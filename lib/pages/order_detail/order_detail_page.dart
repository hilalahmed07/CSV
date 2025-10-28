import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import '../../models/order_status.dart';
import '../../models/driver_model.dart';
import '../../services/order_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/secrets_manager.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailPage({
    Key? key,
    required this.orderId,
    required this.orderData,
  }) : super(key: key);

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _driverLocation;
  StreamSubscription? _driverLocationSubscription;
  bool _isSubmittingReview = false;
  bool _isAddingTip = false;
  final TextEditingController _tipController = TextEditingController();
  Future<DriverModel?>? _driverFuture;
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _setupDriverLocationListener();
    _checkAndShowReviewDialog();
    _loadDriverData();
  }

  void _loadDriverData() {
    final driverId = widget.orderData['driverId'];
    if (driverId != null) {
      _driverFuture = FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get()
          .then((doc) {
            if (doc.exists) {
              return DriverModel.fromFirestore(doc);
            }
            return null;
          });
    }
  }

  void _setupDriverLocationListener() {
    final driverId = widget.orderData['driverId'];
    if (driverId != null) {
      _driverLocationSubscription = FirebaseFirestore.instance
          .collection('driver-locations')
          .doc(driverId)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data != null) {
                setState(() {
                  _driverLocation = LatLng(
                    data['latitude'] as double,
                    data['longitude'] as double,
                  );
                  _updateMarkers();
                });
              }
            }
          });
    }
  }

  void _updateMarkers() {
    final pickupLocation = widget.orderData['pickupLocation'];
    final dropoffLocation = widget.orderData['dropoffLocation'];

    _markers.clear();

    // Add pickup location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          pickupLocation['latitude'] as double,
          pickupLocation['longitude'] as double,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: pickupLocation['name'],
        ),
      ),
    );

    // Add dropoff location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(
          dropoffLocation['latitude'] as double,
          dropoffLocation['longitude'] as double,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Dropoff Location',
          snippet: dropoffLocation['name'],
        ),
      ),
    );

    // Add driver location marker if available
    if (_driverLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Driver Location',
            snippet: 'Live location',
          ),
        ),
      );
    }

    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    if (_mapController == null || _markers.isEmpty) return;

    final bounds = _boundsFromLatLngList(
      _markers.map((marker) => marker.position).toList(),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;

    for (final latLng in list) {
      if (minLat == null || latLng.latitude < minLat) {
        minLat = latLng.latitude;
      }
      if (maxLat == null || latLng.latitude > maxLat) {
        maxLat = latLng.latitude;
      }
      if (minLng == null || latLng.longitude < minLng) {
        minLng = latLng.longitude;
      }
      if (maxLng == null || latLng.longitude > maxLng) {
        maxLng = latLng.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _mapController?.dispose();
    _tipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickupLocation = widget.orderData['pickupLocation'];
    final dropoffLocation = widget.orderData['dropoffLocation'];
    final pickupLocationName = pickupLocation['name'] as String;
    final pickupLatitude = pickupLocation['latitude'] as double;
    final pickupLongitude = pickupLocation['longitude'] as double;
    final pickupDate = (widget.orderData['pickupDate'] as Timestamp).toDate();
    final slotTime = widget.orderData['slotTime'] as String;
    final amount = widget.orderData['amount'];
    final status = OrderStatus.fromString(widget.orderData['status']);

    // Calculate center point between pickup and dropoff
    final pickupLat = pickupLocation['latitude'] ?? 0.0;
    final pickupLng = pickupLocation['longitude'] ?? 0.0;
    final dropoffLat = dropoffLocation['latitude'] ?? 0.0;
    final dropoffLng = dropoffLocation['longitude'] ?? 0.0;

    final centerLat = (pickupLat + dropoffLat) / 2;
    final centerLng = (pickupLng + dropoffLng) / 2;

    return GestureDetector(
      onTap: () {
        // Unfocus any focused input field
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _fitMapToMarkers,
              tooltip: 'Center Map',
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _updateMarkers();
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(centerLat, centerLng),
                        zoom: 12,
                      ),
                      markers: _markers,
                      // zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      // rotateGesturesEnabled: true,
                      // tiltGesturesEnabled: true,
                      // myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      // mapToolbarEnabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${widget.orderId}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(status),
                                    color: _getStatusColor(status),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    status.displayName,
                                    style: TextStyle(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildLocationInfo(
                          'Pickup',
                          pickupLocation['name'],
                          Icons.location_on,
                          Colors.green,
                        ),
                        const SizedBox(height: 16),
                        _buildLocationInfo(
                          'Delivery',
                          dropoffLocation['name'],
                          Icons.location_on,
                          Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  slotTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MM/dd/yyyy').format(pickupDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '\$${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (widget.orderData['driverId'] != null) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Driver Selected',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FutureBuilder<DriverModel?>(
                                  future: _driverFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Error loading driver data',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      );
                                    }

                                    final driver = snapshot.data;
                                    if (driver == null) {
                                      return const Center(
                                        child: Text('Driver not found'),
                                      );
                                    }

                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundImage:
                                              driver.photoUrl != null
                                                  ? NetworkImage(
                                                    driver.photoUrl!,
                                                  )
                                                  : null,
                                          child:
                                              driver.photoUrl == null
                                                  ? const Icon(Icons.person)
                                                  : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                driver.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    size: 16,
                                                    color: Colors.yellow[700],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    driver.rating
                                                        .toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (driver.truckInfo != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Truck: ${driver.truckInfo!['truckType']} (${driver.truckInfo!['truckSize']})',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (driver.truckInfo != null &&
                                            driver.truckInfo!.containsKey(
                                              'truckImageURL',
                                            ) &&
                                            driver.truckInfo!['truckImageURL'] !=
                                                null &&
                                            driver.truckInfo!['truckImageURL']
                                                .toString()
                                                .isNotEmpty)
                                          Image.network(
                                            driver.truckInfo!['truckImageURL'],
                                            height: 60,
                                            width: 60,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const SizedBox(),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Price Breakdown Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cost Breakdown',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Base Charge'),
                                    Text(
                                      '\$${widget.orderData['freightCharge']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Freight Charge'),
                                    Text(
                                      '\$${widget.orderData['freightCharge']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Pick Up Fee'),
                                    Text(
                                      '\$${widget.orderData['pickupFee']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                  ],
                                ),
                                if (widget.orderData['payoutValue'] !=
                                    null) ...[
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Scrap Value'),
                                      Text(
                                        '\$${widget.orderData['payoutValue']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '\$${(widget.orderData['amount'] - (widget.orderData['payoutValue'] ?? 0)).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Pick up amount will be refunded to you once delivery is completed based on the value of the scrap.',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.orderData['scrapImageUrl'] != null) ...[
                          const Text(
                            'Scrap Picture',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.orderData['scrapImageUrl'],
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (status == OrderStatus.rejected) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rejection Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (widget.orderData['rejectionReason'] !=
                                    null) ...[
                                  Text(
                                    widget.orderData['rejectionReason'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (widget.orderData['rejectionImageUrl'] !=
                                    null) ...[
                                  const Text(
                                    'Rejection Image',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      widget.orderData['rejectionImageUrl'],
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (widget.orderData['pickupImageUrl'] != null) ...[
                          const Text(
                            'Pickup Picture',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.orderData['pickupImageUrl'],
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (widget.orderData['receiptImageUrl'] != null) ...[
                          const Text(
                            'Receipt',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF2ECC71),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.orderData['receiptImageUrl'],
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (widget.orderData['totalWeight'] !=
                                    null) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total Weight'),
                                        Text(
                                          '${widget.orderData['totalWeight']?.toStringAsFixed(0) ?? '0'} KG',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (widget.orderData['payoutValue'] !=
                                    null) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Scrap Value'),
                                        Text(
                                          '\$${widget.orderData['payoutValue']?.toStringAsFixed(2) ?? '0.00'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (status == OrderStatus.delivered) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add Tip',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2ECC71),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: TextField(
                                          controller: _tipController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText: 'Enter tip amount',
                                            prefixText: '\$',
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 50,
                                      width: 100,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isAddingTip ? null : _addTip,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF2ECC71,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child:
                                            _isAddingTip
                                                ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                                : const Text(
                                                  'Add Tip',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.orderData['tipAmount'] != null &&
                                    widget.orderData['tipAmount'] > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Current Tip',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          '\$${widget.orderData['tipAmount'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2ECC71),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (status == OrderStatus.pending)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showCancelOrderDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(
    String label,
    String location,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(location),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () {
            // TODO: Implement copy to clipboard
          },
        ),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.pickupComplete:
        return Colors.blue;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.pickupComplete:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.rejected:
        return Icons.block;
    }
  }

  Future<void> _checkAndShowReviewDialog() async {
    if (widget.orderData['status'] == 'delivered' &&
        (widget.orderData['userReview'] == null ||
            widget.orderData['userReview'] == false)) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _showReviewDialog();
      }
    }
  }

  Future<void> _showReviewDialog() async {
    double rating = 0;
    final TextEditingController reviewController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Rate Your Experience'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('How was your experience with the driver?'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 32,
                              ),
                              onPressed: () {
                                setState(() {
                                  rating = index + 1;
                                });
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: reviewController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Share your experience (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed:
                                rating > 0
                                    ? () async {
                                      Navigator.of(context).pop();
                                      await _submitReview(
                                        rating,
                                        reviewController.text,
                                      );
                                    }
                                    : null,
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  rating > 0 ? const Color(0xFF2ECC71) : null,
                              foregroundColor: rating > 0 ? Colors.white : null,
                            ),
                            child: const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _submitReview(double rating, String review) async {
    if (_isSubmittingReview) return;

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      final driverId = widget.orderData['driverId'];
      final batch = FirebaseFirestore.instance.batch();

      // Add review to driver_reviews collection
      final reviewRef =
          FirebaseFirestore.instance.collection('driver_reviews').doc();
      batch.set(reviewRef, {
        'driverId': driverId,
        'orderId': widget.orderId,
        'rating': rating,
        'review': review,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update order to mark as reviewed
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId);
      batch.update(orderRef, {'userReview': true});

      // Calculate new average rating
      final reviewsSnapshot =
          await FirebaseFirestore.instance
              .collection('driver_reviews')
              .where('driverId', isEqualTo: driverId)
              .get();

      final totalReviews = reviewsSnapshot.docs.length;
      final totalRating = reviewsSnapshot.docs.fold<double>(
        0,
        (sum, doc) => sum + (doc.data()['rating'] as num).toDouble(),
      );

      final newAverageRating = (totalRating + rating) / (totalReviews + 1);

      // Update driver's average rating
      final driverRef = FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId);
      batch.update(driverRef, {'rating': newAverageRating});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isSubmittingReview = false;
      });
    }
  }

  Future<void> _addTip() async {
    if (_isAddingTip) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final tipAmount = double.tryParse(_tipController.text);
    if (tipAmount == null || tipAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid tip amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAddingTip = true;
    });

    try {
      // Create payment intent for tip
      final paymentIntentResponse = await _createPaymentIntent(
        (tipAmount * 100).toStringAsFixed(0),
        'USD',
      );

      // Initialize payment sheet
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentResponse['clientSecret'],
          style: ThemeMode.light,
          merchantDisplayName: 'CVS Recycle',
        ),
      );

      // Display payment sheet
      try {
        await stripe.Stripe.instance.presentPaymentSheet();
      } on stripe.StripeException catch (e) {
        print(e);
        throw Exception('Payment failed');
      }

      // Update order with new tip amount
      final batch = FirebaseFirestore.instance.batch();
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId);

      // Get current tip amount
      final orderDoc = await orderRef.get();
      final currentTipAmount = orderDoc.data()?['tipAmount'] ?? 0.0;

      // Update tip amount
      batch.update(orderRef, {
        'tipAmount': currentTipAmount + tipAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tip added successfully!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
        _tipController.clear();

        // Refresh the page by getting the latest order data
        final updatedOrderDoc = await orderRef.get();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OrderDetailPage(
                    orderId: widget.orderId,
                    orderData: updatedOrderDoc.data()!,
                  ),
            ),
          );
        }
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add tip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingTip = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _createPaymentIntent(
    String amount,
    String currency,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email;
    final userId = user?.uid;
    final transactionId =
        'CVS_TIP_${DateTime.now().millisecondsSinceEpoch}_${userId?.substring(0, 8)}';

    final body = {
      'amount': amount,
      'currency': currency,
      'payment_method_types[]': 'card',
      'description': 'CVS Recycling Tip Payment',
      'capture_method': 'automatic',
      'receipt_email': userEmail,
      // 'confirm': true,
      // 'payment_method_options': {
      //   'card': {'capture_method': 'automatic'},
      // },
      'metadata': {
        'user_email': userEmail.toString(),
        'user_id': userId.toString(),
        'transaction_id': transactionId.toString(),
        'order_id': widget.orderId,
        'type': 'tip',
      },
    };

    final stripeSecretKey = await SecretsManager().getSecret(
      'CVS_App_Stripe_SK',
    );

    final dio = Dio();
    try {
      final response = await dio.post(
        'https://api.stripe.com/v1/payment_intents',
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $stripeSecretKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      print('Payment Intent Response is:---> ${response.data}');

      return {
        'paymentIntentId': response.data['id'],
        'clientSecret': response.data['client_secret'],
      };
    } on DioException catch (e) {
      print(e);
      throw Exception('Payment Intent failed');
    }
  }

  Future<void> _showCancelOrderDialog() async {
    final TextEditingController reasonController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Cancel Order'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Please provide a reason for cancelling this order:',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          hintText: 'Enter reason for cancellation',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                if (reasonController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please provide a reason for cancellation',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => isLoading = true);

                                try {
                                  await _orderService.cancelOrder(
                                    widget.orderId,
                                    reasonController.text.trim(),
                                  );

                                  if (mounted) {
                                    Navigator.pop(context); // Close dialog
                                    Navigator.pop(
                                      context,
                                    ); // Go back to orders list
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Order cancelled successfully',
                                        ),
                                        backgroundColor: Color(0xFF2ECC71),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to cancel order: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => isLoading = false);
                                  }
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text('Cancel Order'),
                    ),
                  ],
                ),
          ),
    );
  }
}
