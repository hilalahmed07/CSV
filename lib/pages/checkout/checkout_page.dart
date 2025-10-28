import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/driver_model.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/settings_service.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../../utils/secrets_manager.dart';

class CheckoutPage extends StatefulWidget {
  final OrderModel orderData;
  final DriverModel selectedDriver;
  final File scrapImage;

  const CheckoutPage({
    Key? key,
    required this.orderData,
    required this.selectedDriver,
    required this.scrapImage,
  }) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  final OrderService _orderService = OrderService();
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = false;
  bool _isLoadingSettings = true;
  double? _distanceInMiles;
  double? baseCharge;
  double? ratePerMile;
  double _tipAmount = 0.0;
  final TextEditingController _tipController = TextEditingController();

  String? paymentIntent;
  // String? paymentIntentId;

  // Calculate costs
  double get freightCharge => (_distanceInMiles ?? 0) * (ratePerMile ?? 0);
  String get pickupFee => 'TBD'; // Pickup fee is TBD
  double get totalAmount =>
      (baseCharge ?? 0) +
      freightCharge +
      _tipAmount; // Base charge + freight charge + tip (pickup fee is TBD)

  @override
  void initState() {
    super.initState();
    _createMarkers();
    _calculateDistance();
    _loadSettings();
  }

  Future<void> confirmPayment() async {
    try {
      final confirmPayment = await Stripe.instance.confirmPaymentSheetPayment();

      paymentIntent = null;
      print('Payment is CONFIRMED');
    } catch (e) {
      print('Error is:---> $e');
      // paymentIntentId = null;
    }
  }

  Future<String?> displayPaymentSheet(String paymentIntentId) async {
    try {
      return await Stripe.instance
          .presentPaymentSheet()
          .then((value) async {
            //Clear paymentIntent variable after successful payment
            // await confirmPayment();
            print('Payment Sheet COMPLETED ${paymentIntentId}');
            return paymentIntentId;
          })
          .onError((error, stackTrace) {
            throw Exception(error);
          });
    } on StripeException catch (e) {
      print('Error is:---> $e');
      throw Exception(e);
    } catch (e) {
      print('Error is:---> $e');
      throw Exception(e);
    }
  }

  createPaymentIntent(String amount, String currency) async {
    try {
      final user = getCurrentUser();
      final userEmail = user?.email;

      print('User Email is:---> $userEmail');
      final userId = user?.uid;
      print('User ID is:---> $userId');
      final transactionId =
          'CVS_${DateTime.now().millisecondsSinceEpoch}_${userId?.substring(0, 8)}';

      //Request body
      final body = {
        'amount': amount,
        'currency': currency,
        'payment_method_types[]': 'card',
        'description': 'CVS Recycling Payment',
        'capture_method': 'manual',
        'receipt_email': userEmail,
        'payment_method_options': {
          'card': {'capture_method': 'manual'},
        },
        // 'confirm': true,
        // 'automatic_payment_methods': {'enabled': true},
        // TODO: Add metadata
        'metadata': {
          'user_email': userEmail.toString(),
          'user_id': userId.toString(),
          'transaction_id': transactionId.toString(),
        },
      };

      print('Body is:---> $body');

      final stripeSecretKey = await SecretsManager().getSecret(
        'CVS_App_Stripe_SK',
      );

      //Make post request to Stripe
      final dio = Dio();
      var response = await dio.post(
        'https://api.stripe.com/v1/payment_intents',
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $stripeSecretKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      print('Response is:---> ${response.data}');

      final data = response.data;
      return {
        'paymentIntentId': data['id'],
        'clientSecret': data['client_secret'],
      };
    } on DioException catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        print('Error is:---> ${e.response?.data}');
        // print('Error is:---> ${e.response?.headers}');
        // print('Error is:---> ${e.response?.requestOptions}');
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        throw Exception(e.message);
      }
    }
  }

  Future<void> makePayment() async {
    setState(() {
      _isLoading = true;
    });
    try {
      //STEP 1: Create Payment Intent
      final paymentIntentResponse = await createPaymentIntent(
        (totalAmount * 100).toStringAsFixed(0),
        'USD',
      );

      print('Payment Intent is:---> ${paymentIntentResponse}');

      //STEP 2: Initialize Payment Sheet
      await Stripe.instance
          .initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret:
                  paymentIntentResponse['clientSecret'], //Gotten from payment intent
              style: ThemeMode.light,
              merchantDisplayName: 'Ikay',
            ),
          )
          .then((value) {
            print('Payment Sheet is:---> ${value}');
          });

      print('Payment Sheet INITIALIZED ');

      //STEP 3: Display Payment sheet
      final paymentIntentIdResponse = await displayPaymentSheet(
        paymentIntentResponse['paymentIntentId'],
      );
      if (paymentIntentIdResponse == null) {
        throw Exception(
          'Payment Sheet Displayed but Payment Intent ID is NULL',
        );
      }
      print('Payment Sheet DISPLAYED ${paymentIntentIdResponse}');

      //STEP 4: Write Payment Intent ID to Firestore
      await _handleCheckout(paymentIntentIdResponse);
    } catch (err) {
      print('Error is:---> ONE: $err');
      throw Exception(err);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getSettings();
      if (mounted) {
        setState(() {
          baseCharge = settings['baseOrderPrice']?.toDouble() ?? 5.0;
          ratePerMile = settings['perMilePrice']?.toDouble() ?? 2.0;
          _isLoadingSettings = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() {
          baseCharge = 5.0;
          ratePerMile = 2.0;
          _isLoadingSettings = false;
        });
      }
    }
  }

  Future<void> _calculateDistance() async {
    try {
      double distanceInMeters = Geolocator.distanceBetween(
        widget.orderData.pickupLatitude,
        widget.orderData.pickupLongitude,
        widget.orderData.scrapyardLatitude,
        widget.orderData.scrapyardLongitude,
      );

      // Convert meters to miles (1 mile = 1609.34 meters)
      setState(() {
        _distanceInMiles = distanceInMeters / 1609.34;
      });
    } catch (e) {
      print('Error calculating distance: $e');
      setState(() {
        _distanceInMiles = 0;
      });
    }
  }

  void _createMarkers() {
    // Add pickup location marker
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          widget.orderData.pickupLatitude,
          widget.orderData.pickupLongitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Pick Up Location"),
      ),
    );

    // Add drop-off location marker
    markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(
          widget.orderData.scrapyardLatitude,
          widget.orderData.scrapyardLongitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.orderData.scrapyardName),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    if (mapController == null || markers.isEmpty) return;

    final bounds = _boundsFromLatLngList(
      markers.map((marker) => marker.position).toList(),
    );

    // Add padding to ensure markers are visible
    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        50,
      ), // Reduced padding from 100 to 50
    );
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

  Future<void> _handleCheckout(String paymentIntentId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _orderService.createOrder(
        orderData: widget.orderData,
        driver: widget.selectedDriver,
        totalAmount: totalAmount,
        freightCharge: freightCharge,
        pickupFee: 0, // Since it's TBD, we'll set it to 0 initially
        scrapImage: widget.scrapImage,
        paymentIntentId: paymentIntentId,
        tipAmount: _tipAmount, // Add tip amount to the order
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order has been created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  String? getCurrentUserEmail() {
    final user = getCurrentUser();
    return user?.email;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    if (_isLoadingSettings) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: () {
        // Unfocus any focused input field
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map Section
              SizedBox(
                height: 200,
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.orderData.pickupLatitude,
                      widget.orderData.pickupLongitude,
                    ),
                    zoom: 12.0,
                  ),
                  markers: markers,
                  myLocationButtonEnabled: false,
                  myLocationEnabled: false,
                ),
              ),
              const SizedBox(height: 20),
              // Pickup and Delivery Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup and Delivery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pickup',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(widget.orderData.pickupLocationName),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(widget.orderData.scrapyardName),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.access_time),
                        const SizedBox(width: 8),
                        const Text('Time: '),
                        Text(
                          widget.orderData.slotTime,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Date: '),
                        Text(
                          DateFormat(
                            'MM/dd/yyyy',
                          ).format(widget.orderData.pickupDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Driver Details
              Padding(
                padding: const EdgeInsets.all(16),
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              widget.selectedDriver.photoUrl != null
                                  ? NetworkImage(
                                    widget.selectedDriver.photoUrl!,
                                  )
                                  : null,
                          child:
                              widget.selectedDriver.photoUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.selectedDriver.name,
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
                                    widget.selectedDriver.rating.toString(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          'assets/images/truck.png',
                          height: 60,
                          width: 60,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrap Picture
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scrap Picture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        widget.scrapImage,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Cost Breakdown Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Material(
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Distance'),
                            Text(
                              '${_distanceInMiles?.toStringAsFixed(1) ?? "0.0"} miles',
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Base Charge'),
                            Text(currencyFormat.format(baseCharge ?? 0)),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Freight Charge'),
                            Text(
                              '${currencyFormat.format(freightCharge)} (${currencyFormat.format(ratePerMile ?? 0)}/mile)',
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [Text('Pick Up Fee'), Text('TBD')],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tip'),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _tipController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '\$',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _tipAmount = double.tryParse(value) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              currencyFormat.format(totalAmount),
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
              ),
              // Checkout Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // onPressed: _isLoading ? null : _handleCheckout,
                    onPressed: _isLoading ? null : makePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tipController.dispose();
    mapController?.dispose();
    super.dispose();
  }
}
