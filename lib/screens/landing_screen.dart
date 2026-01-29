import 'dart:math';
import 'package:flutter/material.dart';
import 'user_login_screen.dart';
import 'admin_login_screen.dart';
import 'loading_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation1;
  late Animation<Color?> _colorAnimation2;
  final Random _random = Random();
  final int _particleCount = 40;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _colorAnimation1 =
        ColorTween(begin: Colors.black, end: Colors.grey[900])
            .animate(_controller);
    _colorAnimation2 =
        ColorTween(begin: Colors.grey[850], end: Colors.black87)
            .animate(_controller);

    // Initialize particles behind the logo
    _particles = List.generate(
      _particleCount,
          (index) => _Particle(
        x: 0.5 + (_random.nextDouble() - 0.5) * 0.4,
        y: 1.0 + _random.nextDouble() * 0.5,
        size: 3 + _random.nextDouble() * 6,
        speedY: 0.002 + _random.nextDouble() * 0.003,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate(String type) {
    if (type == 'user') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
      );
    } else if (type == 'admin') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _colorAnimation1.value!,
                      _colorAnimation2.value!,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                // Back Arrow
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>  LoadingScreen()),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo with upward bubbles
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Particle effect behind logo
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (_, __) {
                                    for (var p in _particles) {
                                      p.y -= p.speedY;
                                      if (p.y < -0.1) {
                                        p.y = 1.0 + _random.nextDouble() * 0.3;
                                        p.x = 0.5 +
                                            (_random.nextDouble() - 0.5) * 0.4;
                                        p.size = 3 + _random.nextDouble() * 6;
                                        p.speedY =
                                            0.002 + _random.nextDouble() * 0.003;
                                      }
                                    }
                                    return CustomPaint(
                                      size: const Size(170, 170),
                                      painter: _ParticlePainter(_particles),
                                    );
                                  },
                                ),
                                // Circular logo
                                Container(
                                  width: 140,
                                  height: 140,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white24, width: 2),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 50),
                          const Text(
                            "Welcome",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Login to continue",
                            style: TextStyle(color: Colors.white54),
                          ),
                          const SizedBox(height: 40),
                          // User Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => _navigate('user'),
                              child: const Text('User Login'),
                            ),
                          ),
                          const SizedBox(height: 25),
                          // Admin Login Button
                          TextButton(
                            onPressed: () => _navigate('admin'),
                            child: const Text(
                              'Admin Login',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
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
}

// ===== PARTICLE MODEL =====
class _Particle {
  double x, y, size, speedY;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedY,
  });
}

// ===== PARTICLE PAINTER =====
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white24;
    for (var p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}