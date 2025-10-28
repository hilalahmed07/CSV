import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import '../../models/scrapyard_model.dart';
import 'dart:io';
import '../../models/order_model.dart';
import '../driver_selection/driver_selection_page.dart';
import '../checkout/checkout_page.dart';
import '../../services/location_service.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/secrets_manager.dart';

class ScrapyardDetailPage extends StatefulWidget {
  final ScrapyardModel scrapyard;
  final Position userPosition;

  const ScrapyardDetailPage({
    Key? key,
    required this.scrapyard,
    required this.userPosition,
  }) : super(key: key);

  @override
  State<ScrapyardDetailPage> createState() => _ScrapyardDetailPageState();
}

class _ScrapyardDetailPageState extends State<ScrapyardDetailPage> {
  maps.GoogleMapController? mapController;
  Set<maps.Marker> markers = {};
  DateTime? selectedDate;
  String? selectedTimeSlot;
  String? uploadedImagePath;
  final TextEditingController locationController = TextEditingController();
  String? _googleApiKey;
  Position? _currentPosition;
  String? _currentLocationName;
  final _imagePicker = ImagePicker();

  final List<String> timeSlots = [
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 1:00 PM',
    '1:00 PM - 2:00 PM',
    '2:00 PM - 3:00 PM',
  ];

  List<String> getAvailableTimeSlots() {
    final now = DateTime.now();
    final twoHoursFromNow = now.add(const Duration(hours: 2));

    // If selected date is today, filter slots
    if (selectedDate?.year == now.year &&
        selectedDate?.month == now.month &&
        selectedDate?.day == now.day) {
      return timeSlots.where((slot) {
        final slotTime = _parseSlotTime(slot);
        return slotTime.isAfter(twoHoursFromNow);
      }).toList();
    }

    // If selected date is future date, show all slots
    return timeSlots;
  }

  DateTime _parseSlotTime(String slot) {
    final time = slot.split(' - ')[0]; // Get start time
    final isPM = time.contains('PM');
    final hour = int.parse(time.split(':')[0]);
    final minute = int.parse(time.split(':')[1].split(' ')[0]);

    final date = selectedDate ?? DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
      isPM && hour != 12
          ? hour + 12
          : hour == 12 && !isPM
          ? 0
          : hour,
      minute,
    );
  }

  @override
  void initState() {
    super.initState();
    _setupMarkers();
    _loadGoogleApiKey();
  }

  Future<void> _loadGoogleApiKey() async {
    try {
      final apiKey = await SecretsManager().getSecret('CVS_App_Places_API_Key');
      print('Google API Key: $apiKey');
      setState(() {
        _googleApiKey = apiKey;
      });
    } catch (e) {
      print('Error loading Google API key: $e');
    }
  }

  void _setupMarkers() {
    // Add scrapyard marker
    markers.add(
      maps.Marker(
        markerId: maps.MarkerId(widget.scrapyard.id),
        position: maps.LatLng(
          double.parse(widget.scrapyard.latitude),
          double.parse(widget.scrapyard.longitude),
        ),
        infoWindow: maps.InfoWindow(
          title: widget.scrapyard.name,
          snippet: 'Open till ${widget.scrapyard.openTill}',
        ),
      ),
    );

    // Add user location marker
    markers.add(
      maps.Marker(
        markerId: const maps.MarkerId('pickup'),
        position: maps.LatLng(
          widget.userPosition.latitude,
          widget.userPosition.longitude,
        ),
        infoWindow: const maps.InfoWindow(title: 'Your Location'),
        icon: maps.BitmapDescriptor.defaultMarkerWithHue(
          maps.BitmapDescriptor.hueBlue,
        ),
      ),
    );
  }

  void _onMapCreated(maps.GoogleMapController controller) {
    mapController = controller;
    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    if (mapController == null) return;

    final List<maps.LatLng> latLngList =
        markers.map((marker) => marker.position).toList();

    final bounds = _boundsFromLatLngList(latLngList);
    mapController!.animateCamera(
      maps.CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  maps.LatLngBounds _boundsFromLatLngList(List<maps.LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;

    for (final latLng in list) {
      minLat =
          minLat == null
              ? latLng.latitude
              : minLat < latLng.latitude
              ? minLat
              : latLng.latitude;
      maxLat =
          maxLat == null
              ? latLng.latitude
              : maxLat > latLng.latitude
              ? maxLat
              : latLng.latitude;
      minLng =
          minLng == null
              ? latLng.longitude
              : minLng < latLng.longitude
              ? minLng
              : latLng.longitude;
      maxLng =
          maxLng == null
              ? latLng.longitude
              : maxLng > latLng.longitude
              ? maxLng
              : latLng.longitude;
    }

    return maps.LatLngBounds(
      southwest: maps.LatLng(minLat!, minLng!),
      northeast: maps.LatLng(maxLat!, maxLng!),
    );
  }

  void _updatePickupMarker(double lat, double lng, String name) {
    setState(() {
      markers.removeWhere((marker) => marker.markerId.value == 'pickup');
      markers.add(
        maps.Marker(
          markerId: const maps.MarkerId('pickup'),
          position: maps.LatLng(lat, lng),
          infoWindow: maps.InfoWindow(title: 'Pickup', snippet: name),
          icon: maps.BitmapDescriptor.defaultMarkerWithHue(
            maps.BitmapDescriptor.hueGreen,
          ),
        ),
      );
      _currentPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _currentLocationName = name;
    });

    mapController?.animateCamera(
      maps.CameraUpdate.newLatLng(maps.LatLng(lat, lng)),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
        // Reset time slot when date changes
        selectedTimeSlot = null;
      });
    }
  }

  void _selectTimeSlot(String slot) {
    setState(() {
      selectedTimeSlot = slot;
    });
  }

  Future<void> _handleImageUpload() async {
    try {
      final result = await showDialog<ImageSource>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Select Source'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
      );

      if (result != null) {
        final XFile? image = await _imagePicker.pickImage(
          source: result,
          imageQuality: 80,
        );

        if (image != null) {
          setState(() {
            uploadedImagePath = image.path;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  bool _validateForm() {
    return locationController.text.isNotEmpty &&
        selectedDate != null &&
        selectedTimeSlot != null &&
        uploadedImagePath != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: maps.GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: maps.CameraPosition(
                    target: maps.LatLng(
                      double.parse(widget.scrapyard.latitude),
                      double.parse(widget.scrapyard.longitude),
                    ),
                    zoom: 12.0,
                  ),
                  markers: markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapType: maps.MapType.normal,
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup from?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GooglePlacesAutoCompleteTextFormField(
                      textEditingController: locationController,
                      googleAPIKey: _googleApiKey ?? '',
                      debounceTime: 400,
                      countries: ["us"],
                      fetchCoordinates: true,
                      onPlaceDetailsWithCoordinatesReceived: (prediction) {
                        if (prediction.lat != null && prediction.lng != null) {
                          _updatePickupMarker(
                            double.parse(prediction.lat!),
                            double.parse(prediction.lng!),
                            prediction.description ?? '',
                          );
                        }
                      },
                      onSuggestionClicked: (prediction) {
                        locationController.text = prediction.description ?? '';
                        locationController
                            .selection = TextSelection.fromPosition(
                          TextPosition(
                            offset: (prediction.description ?? '').length,
                          ),
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter pickup location...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: () {
                            // Implement get current location functionality
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select pick up date',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              selectedDate != null
                                  ? '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}'
                                  : 'Select Date',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF2ECC71),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedDate != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select time slot',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final availableSlots = getAvailableTimeSlots();
                          if (availableSlots.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Text(
                                'No time slots available for the selected date. Please select a different date.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                availableSlots.map((slot) {
                                  final isSelected = selectedTimeSlot == slot;
                                  return InkWell(
                                    onTap: () => _selectTimeSlot(slot),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? const Color(0xFF2ECC71)
                                                : Colors.white,
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? const Color(0xFF2ECC71)
                                                  : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        slot,
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Scrapped Metal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _handleImageUpload,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            uploadedImagePath != null
                                ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(uploadedImagePath!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 32,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Upload Picture',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Take a photo or select from gallery',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _validateForm()
                                ? () {
                                  if (_currentPosition == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please wait while we get your location',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final order = OrderModel(
                                    scrapyardId: widget.scrapyard.id,
                                    scrapyardName: widget.scrapyard.name,
                                    scrapyardLatitude: double.parse(
                                      widget.scrapyard.latitude,
                                    ),
                                    scrapyardLongitude: double.parse(
                                      widget.scrapyard.longitude,
                                    ),
                                    pickupLocationName:
                                        _currentLocationName ??
                                        locationController.text,
                                    pickupLatitude: _currentPosition!.latitude,
                                    pickupLongitude:
                                        _currentPosition!.longitude,
                                    pickupDate: selectedDate!,
                                    slotTime: selectedTimeSlot!,
                                    scrapImageUrl: uploadedImagePath!,
                                    pickupState: widget.scrapyard.state,
                                    pickupCity: widget.scrapyard.city,
                                  );

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => DriverSelectionPage(
                                            orderData: order,
                                            scrapImage: File(
                                              uploadedImagePath!,
                                            ),
                                          ),
                                    ),
                                  );
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Next: Select Driver',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
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
    mapController?.dispose();
    locationController.dispose();
    super.dispose();
  }
}
