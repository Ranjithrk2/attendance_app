import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Register the member's face embedding
  static Future<void> registerMemberFace({
    required String ownerUid,
    required String memberId, // must be auth.uid
    required List<double> faceEmbedding,
  }) async {
    // Save under 'users/{memberId}' document
    await _db.collection('users').doc(memberId).set({
      'ownerUid': ownerUid,
      'masterFaceEmbedding': faceEmbedding,
      'masterFaceBase64': null, // optional: store if needed
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // merge: keep existing fields
  }

  /// Optional: Update masterFaceBase64 after capturing photo
  static Future<void> updateMasterFaceBase64({
    required String memberId,
    required String base64Image,
  }) async {
    await _db.collection('users').doc(memberId).set({
      'masterFaceBase64': base64Image,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch user document by auth.uid
  static Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String memberId) async {
    return await _db.collection('users').doc(memberId).get();
  }
}