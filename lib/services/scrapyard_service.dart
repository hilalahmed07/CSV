import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scrapyard_model.dart';

class ScrapyardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get scrapyards filtered by city
  Stream<List<ScrapyardModel>> getScrapyards({String? city}) {
    Query query = _firestore.collection('scrapyards');

    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ScrapyardModel.fromJson({'id': doc.id, ...data});
      }).toList();
    });
  }

  // Get a single scrapyard by ID
  Future<ScrapyardModel?> getScrapyardById(String id) async {
    final doc = await _firestore.collection('scrapyards').doc(id).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return ScrapyardModel.fromJson({'id': doc.id, ...data});
    }
    return null;
  }
}
