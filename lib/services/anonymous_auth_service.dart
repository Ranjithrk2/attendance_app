import 'package:firebase_auth/firebase_auth.dart';

class AnonymousAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in anonymously
  static Future<User?> signInAnonymously() async {
    try {
      UserCredential credential = await _auth.signInAnonymously();
      print('Signed in anonymously as ${credential.user?.uid}');
      return credential.user;
    } catch (e) {
      print('Anonymous login error: $e');
      return null;
    }
  }

  /// Get current signed-in user
  static User? get currentUser => _auth.currentUser;
}
