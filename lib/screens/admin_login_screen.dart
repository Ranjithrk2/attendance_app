import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart';
import 'landing_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  late AnimationController _particleController;
  final int _particleCount = 40;
  final Random _random = Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      _particleCount,
          (index) => _Particle(
        x: 0.5 + (_random.nextDouble() - 0.5) * 0.5,
        y: 1.0 + _random.nextDouble() * 0.5,
        size: 2 + _random.nextDouble() * 5,
        speedY: 0.002 + _random.nextDouble() * 0.003,
      ),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  /// 🔐 SECURE ADMIN LOGIN
  Future<void> loginAdmin() async {
    setState(() => isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("Login failed");

      // 🔥 FORCE FRESH TOKEN
      await FirebaseAuth.instance.currentUser!.getIdToken(true);

      // Now fetch Firestore role
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists &&
          doc.data()?['role'] == 'admin' &&
          doc.data()?['active'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Not authorized as admin")),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.cyanAccent),
      filled: true,
      fillColor: Colors.white12,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF0A2632)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) {
              for (var p in _particles) {
                p.y -= p.speedY;
                if (p.y < -0.1) {
                  p.y = 1.0 + _random.nextDouble() * 0.5;
                  p.x = 0.5 + (_random.nextDouble() - 0.5) * 0.5;
                }
              }
              return CustomPaint(
                painter: _ParticlePainter(_particles),
                child: Container(),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.admin_panel_settings,
                        size: 80, color: Colors.cyanAccent),
                    const SizedBox(height: 50),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Email'),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Password'),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : loginAdmin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text(
                          "Login as Admin",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LandingScreen()),
                        );
                      },
                      child: const Text("Back to Home",
                          style: TextStyle(color: Colors.cyanAccent)),
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
}

// ================= PARTICLES =================
class _Particle {
  double x, y, size, speedY;
  _Particle({required this.x, required this.y, required this.size, required this.speedY});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.cyanAccent.withOpacity(0.2);
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
