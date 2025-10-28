import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final doc =
          await _firestore.collection('settings').doc('app_settings').get();
      if (doc.exists) {
        return doc.data() ?? {};
      }
      return {'perMilePrice': 2.0, 'baseOrderPrice': 5.0};
    } catch (e) {
      print('Error getting settings: $e');
      return {'perMilePrice': 2.0, 'baseOrderPrice': 5.0};
    }
  }
}
