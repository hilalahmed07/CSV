import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String? photoUrl;
  final double rating;
  final int ordersCompleted;
  final Map<String, dynamic>? truckInfo;
  final bool isActive;
  final String state;
  final String city;

  DriverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.photoUrl,
    required this.rating,
    required this.ordersCompleted,
    this.truckInfo,
    required this.isActive,
    required this.state,
    required this.city,
  });

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DriverModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      photoUrl: data['photoUrl'],
      rating: (data['rating'] ?? 0.0).toDouble(),
      ordersCompleted: data['ordersCompleted'] ?? 0,
      truckInfo: data['truckInfo'] as Map<String, dynamic>?,
      isActive: data['isActive'] ?? false,
      state: data['state'] ?? '',
      city: data['city'] ?? '',
    );
  }
}
