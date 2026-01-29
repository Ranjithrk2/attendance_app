import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'biometric_service.dart';

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _attendance = _firestore.collection('attendance');

  // ============================================================
  // ✅ CHECK-IN (FACE VERIFIED BEFORE CALLING THIS METHOD)
  // ============================================================
  static Future<void> checkIn({
    required String displayUserId, // Firestore userId (NOT uid)
    required String selfieBase64,  // Base64 of selfie image
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      await _attendance.add({
        'userId': user.uid,
        'displayUserId': displayUserId,
        'checkIn': Timestamp.now(),
        'checkOut': null,
        'checkInSelfieBase64': selfieBase64,
        'checkInMethod': 'face',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to check in: $e');
    }
  }

  // ============================================================
  // 🔐 CHECK-OUT (FINGERPRINT / FACE ID ONLY)
  // ============================================================
  static Future<bool> checkOut(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // 1️⃣ Find active check-in
      final snap = await _attendance
          .where('userId', isEqualTo: user.uid)
          .where('checkOut', isNull: true) // ✅ correct syntax
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active check-in found')),
        );
        return false;
      }

      // 2️⃣ Biometric authentication
      final authenticated = await BiometricService.authenticate(context);
      if (!authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed')),
        );
        return false;
      }

      // 3️⃣ Update checkout
      await _attendance.doc(snap.docs.first.id).update({
        'checkOut': Timestamp.now(),
        'checkOutMethod': 'biometric',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout successful ✅')),
      );

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e')),
      );
      return false;
    }
  }

  // ============================================================
  // 📜 USER ATTENDANCE HISTORY
  // ============================================================
  static Future<List<Map<String, dynamic>>> getUserRecords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snap = await _attendance
          .where('userId', isEqualTo: user.uid)
          .orderBy('checkIn', descending: true)
          .get();

      return snap.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })
          .toList();
    } catch (e) {
      print('Error fetching user records: $e');
      return [];
    }
  }

  // ============================================================
  // 🛠 ADMIN – ALL ATTENDANCE RECORDS
  // ============================================================
  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    try {
      final snap = await _attendance
          .orderBy('checkIn', descending: true)
          .get();

      return snap.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })
          .toList();
    } catch (e) {
      print('Error fetching all records: $e');
      return [];
    }
  }
}
