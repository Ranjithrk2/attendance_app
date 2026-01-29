import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_dashboard.dart';

class ForceChangePasswordScreen extends StatefulWidget {
  final String userId;
  const ForceChangePasswordScreen({super.key, required this.userId});

  @override
  State<ForceChangePasswordScreen> createState() =>
      _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  // Background particles
  late AnimationController _bgController;
  final Random _random = Random();
  final int _particleCount = 50;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      _particleCount,
          (_) => _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 2 + _random.nextDouble() * 3,
        speedX: (_random.nextDouble() - 0.5) * 0.002,
        speedY: (_random.nextDouble() - 0.5) * 0.002,
      ),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldPass = _oldPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill both fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final email = userDoc['email'] as String;

      // Reauthenticate
      final cred = EmailAuthProvider.credential(email: email, password: oldPass);
      await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(cred);

      // Update password
      await FirebaseAuth.instance.currentUser!.updatePassword(newPass);

      // Update firstLogin flag
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'firstLogin': false});

      // Navigate to dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserDashboard(
            uid: FirebaseAuth.instance.currentUser!.uid,  // Firebase UID
          ),
        ),
      );


      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully")));
    } on FirebaseAuthException catch (e) {
      String message = "Error updating password";
      if (e.code == 'wrong-password') message = "Old password is incorrect";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated particle background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              for (var p in _particles) {
                p.x += p.speedX;
                p.y += p.speedY;
                if (p.x < 0) p.x += 1;
                if (p.x > 1) p.x -= 1;
                if (p.y < 0) p.y += 1;
                if (p.y > 1) p.y -= 1;
              }
              return CustomPaint(
                painter: _ParticlePainter(_particles),
                child: Container(),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Frosted Glass Panel
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white12.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Change Password",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Old Password
                          _buildPasswordField(
                              controller: _oldPasswordController,
                              label: "Old Password",
                              obscure: _obscureOld,
                              toggle: () => setState(() => _obscureOld = !_obscureOld)),

                          const SizedBox(height: 20),

                          // New Password
                          _buildPasswordField(
                              controller: _newPasswordController,
                              label: "New Password",
                              obscure: _obscureNew,
                              toggle: () => setState(() => _obscureNew = !_obscureNew)),

                          const SizedBox(height: 40),

                          // Update Button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _changePassword,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                      : const Text(
                                    "Update Password",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white12,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
          ),
          onPressed: toggle,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// Particle Model
class _Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
  });
}

// Particle Painter
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white12;
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
