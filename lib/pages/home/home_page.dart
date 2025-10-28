import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/scrapyard_model.dart';
import '../../services/scrapyard_service.dart';
import '../../services/location_service.dart';
import '../../widgets/scrapyard_card.dart';
import '../scrapyard_detail/scrapyard_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? mapController;
  CameraPosition? _currentLocation;
  bool _isLoading = true;
  Position? _userPosition;
  final ScrapyardService _scrapyardService = ScrapyardService();
  final LocationService _locationService = LocationService();
  List<ScrapyardModel> scrapyards = [];
  String? _userCity;

  // Fallback coordinates (Cincinnati)
  static const double fallbackLat = 39.1031;
  static const double fallbackLng = -84.5120;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getUserCity();
  }

  Future<void> _getUserCity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          _userCity = doc.data()?['city'] as String?;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();

      setState(() {
        _userPosition = position;
        _currentLocation = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 12.0,
        );
        _isLoading = false;
      });

      if (mapController != null) {
        await mapController!.animateCamera(
          CameraUpdate.newCameraPosition(_currentLocation!),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentLocation = CameraPosition(
          target: const LatLng(fallbackLat, fallbackLng),
          zoom: 12.0,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error getting location: $e. Using fallback location.',
            ),
          ),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentLocation != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(_currentLocation!),
      );
    }
  }

  double _calculateDistance(ScrapyardModel scrapyard) {
    if (_userPosition == null) return 0;
    return Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          double.parse(scrapyard.latitude),
          double.parse(scrapyard.longitude),
        ) /
        1609.34; // Convert meters to kilometers
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

  Widget _buildScrapyardCard(ScrapyardModel scrapyard) {
    final distance = _calculateDistance(scrapyard);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
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
                      '${distance.toStringAsFixed(1)} miles away from your loc',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: Color(0xFF2ECC71),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${scrapyard.address}, ${scrapyard.state} ${scrapyard.zipCode}',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 4),
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
          ElevatedButton(
            onPressed: () {
              // Handle select action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Set<Marker> _createMarkers() {
    final Set<Marker> markers = {
      // Add user location marker
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(
          _userPosition?.latitude ?? fallbackLat,
          _userPosition?.longitude ?? fallbackLng,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Cincinnati, OH',
        ),
      ),
    };

    // Add scrapyard markers
    markers.addAll(
      scrapyards.map((scrapyard) {
        return Marker(
          markerId: MarkerId(scrapyard.id),
          position: LatLng(
            double.parse(scrapyard.latitude),
            double.parse(scrapyard.longitude),
          ),
          infoWindow: InfoWindow(
            title: scrapyard.name,
            snippet: 'Open till ${scrapyard.openTill}',
          ),
        );
      }),
    );

    return markers;
  }

  void _handleSelectScrapyard(ScrapyardModel scrapyard) {
    if (_userPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for location access')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ScrapyardDetailPage(
              scrapyard: scrapyard,
              userPosition: _userPosition!,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Google Maps taking up half the screen
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition:
                          _currentLocation ??
                          const CameraPosition(
                            target: LatLng(25.1972, 55.2744),
                            zoom: 12.0,
                          ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                      markers: _createMarkers(),
                    ),
          ),
          // Scrapyard listing
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Select scrapyard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<ScrapyardModel>>(
                      stream: _scrapyardService.getScrapyards(city: _userCity),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        scrapyards = snapshot.data ?? [];

                        if (scrapyards.isEmpty) {
                          return const Center(
                            child: Text('No scrapyards available'),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: scrapyards.length,
                          itemBuilder: (context, index) {
                            return ScrapyardCard(
                              scrapyard: scrapyards[index],
                              userPosition: _userPosition,
                              onSelect:
                                  () =>
                                      _handleSelectScrapyard(scrapyards[index]),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _getCurrentLocation,
      //   child: const Icon(Icons.my_location),
      // ),
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}
