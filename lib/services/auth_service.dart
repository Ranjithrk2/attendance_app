import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static AppUser? currentUser;

  // ================= ADMIN CREATE USER =================
  static Future<bool> adminCreateUser({
    required String email,
    required String tempPassword,
    required String userId,
    required String adminEmail,
    required String adminPassword,
  }) async {
    try {
      // 1️⃣ Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      final uid = credential.user!.uid;

      // 2️⃣ Create Firestore user doc
      await _firestore.collection('users').doc(uid).set({
        'userId': userId,
        'email': email,
        'role': 'user',
        'firstLogin': true,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ SIGN ADMIN BACK IN (CRITICAL)
      await _auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      return true;
    } catch (e) {
      print('ADMIN CREATE USER ERROR: $e');
      return false;
    }
  }

  // ================= LOGIN =================
  static Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final doc =
      await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw Exception('User record not found');
      }

      final data = doc.data()!;

      currentUser = AppUser(
        id: uid,
        name: data['userId'],
        role: data['role'],
        firstLogin: data['firstLogin'],
      );

      return currentUser;
    } catch (e) {
      print('LOGIN ERROR: $e');
      return null;
    }
  }

  // ================= FIRST LOGIN CHECK =================
  static Future<bool> isFirstLogin() async {
    final uid = _auth.currentUser!.uid;
    final doc =
    await _firestore.collection('users').doc(uid).get();
    return doc['firstLogin'] == true;
  }

  // ================= CHANGE PASSWORD =================
  static Future<bool> changePassword(String newPassword) async {
    try {
      await _auth.currentUser!.updatePassword(newPassword);

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'firstLogin': false});

      return true;
    } catch (e) {
      print('CHANGE PASSWORD ERROR: $e');
      return false;
    }
  }

  // ================= LOGOUT =================
  static Future<void> logout() async {
    await _auth.signOut();
    currentUser = null;
  }

  // ================= ADMIN CHECK =================
  static bool isAdmin() {
    return currentUser?.role == 'admin';
  }
}