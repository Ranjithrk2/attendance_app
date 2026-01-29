import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_dashboard.dart';
import 'force_change_password_screen.dart';
import 'landing_screen.dart'; // <-- Import your landing screen here

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({Key? key}) : super(key: key);

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _bgController;
  final Random _random = Random();
  final int _particleCount = 50;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _particles = List.generate(
      _particleCount,
          (index) => _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1 + _random.nextDouble() * 2,
        speedX: (_random.nextDouble() - 0.5) * 0.0005,
        speedY: (_random.nextDouble() - 0.5) * 0.0005,
      ),
    );

    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 120))
      ..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter Email & Password")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final uid = userCredential.user!.uid;

      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists || !(userDoc.get('active') as bool? ?? false)) {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account not allowed"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      bool isFirstLogin = userDoc.get('firstLogin') ?? true;
      if (isFirstLogin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ForceChangePasswordScreen(userId: uid)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserDashboard(uid: uid)),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login failed!";
      if (e.code == 'user-not-found') message = "User not found";
      if (e.code == 'wrong-password') message = "Incorrect password";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Particle background
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
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
          SafeArea(
            child: Column(
              children: [
                // Back arrow to LandingScreen
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LandingScreen()),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Futuristic Title
                          Text(
                            "LOGIN PORTAL",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.white24,
                                  blurRadius: 8,
                                  offset: Offset(0, 0),
                                ),
                                Shadow(
                                  color: Colors.white38,
                                  blurRadius: 16,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildTextField(_emailController, "Email", false),
                          const SizedBox(height: 20),
                          _buildTextField(_passwordController, "Password", true),
                          const SizedBox(height: 35),
                          _buildLoginButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, bool isPassword) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        color: Colors.white12,
        boxShadow: [
          BoxShadow(
            color: Colors.white10,
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: _isLoading ? null : _login,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          "LOGIN",
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// Particle Models
class _Particle {
  double x, y, size, speedX, speedY;
  _Particle(
      {required this.x,
        required this.y,
        required this.size,
        required this.speedX,
        required this.speedY});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
