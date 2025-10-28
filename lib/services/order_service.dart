import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';
import '../models/driver_model.dart';
import '../models/order_status.dart';
import '../services/storage_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storageService = StorageService();

  Stream<List<QueryDocumentSnapshot>> getUserOrders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> createOrder({
    required OrderModel orderData,
    required DriverModel driver,
    required double totalAmount,
    required double freightCharge,
    required double pickupFee,
    required File scrapImage,
    required String paymentIntentId,
    required double tipAmount,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Upload the scrap image first
      final scrapImageUrl = await _storageService.uploadScrapImage(scrapImage);

      await _firestore.collection('orders').add({
        'userId': userId,
        'driverId': driver.id,
        'scrapyardId': orderData.scrapyardId,
        'pickupLocation': {
          'name': orderData.pickupLocationName,
          'latitude': orderData.pickupLatitude,
          'longitude': orderData.pickupLongitude,
        },
        'pickupDate': Timestamp.fromDate(orderData.pickupDate),
        'slotTime': orderData.slotTime,
        'dropoffLocation': {
          'name': orderData.scrapyardName,
          'latitude': orderData.scrapyardLatitude,
          'longitude': orderData.scrapyardLongitude,
        },
        'scrapImageUrl': scrapImageUrl,
        // Payment details
        'freightCharge': freightCharge,
        'pickupFee': pickupFee,
        'amount': totalAmount,
        'tipAmount': tipAmount,
        // Driver added fields (to be updated later)
        'receiptImageUrl': null,
        'totalWeight': null,
        'payoutValue': null,
        // Status and metadata
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'driver': {
          'name': driver.name,
          'photoUrl': driver.photoUrl,
          'rating': driver.rating,
          'phoneNumber': driver.phoneNumber,
        },
        'paymentIntentId': paymentIntentId,
      });
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }
}
