import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Authenticate user with fingerprint / FaceID
  static Future<bool> authenticate(BuildContext context) async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication not supported')),
        );
        return false;
      }

      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No biometrics enrolled')),
        );
        return false;
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to check out',
      );
      return authenticated;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: $e')),
      );
      return false;
    }
  }
}