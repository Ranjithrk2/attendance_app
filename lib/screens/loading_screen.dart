import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'landing_screen.dart';

class LoadingScreen extends StatefulWidget {
  final Function(String)? onThemeChanged;
  final bool isDarkMode;

  LoadingScreen({Key? key, this.onThemeChanged, this.isDarkMode = false})
      : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _arcController;
  late AnimationController _tapController;
  late Animation<double> _logoScale;
  late Animation<double> _arcSpeed;
  late Animation<double> _glowOpacity;
  bool _tapped = false;

  Timer? _autoNavigateTimer;

  @override
  void initState() {
    super.initState();

    // Continuous arc rotation
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Animation when logo is tapped or auto triggers
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    _arcSpeed = Tween<double>(begin: 1.0, end: 3.0).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
    );

    _glowOpacity = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeIn),
    );

    _tapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Navigate to LandingScreen when animation completes
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LandingScreen()),
        );
      }
    });

    // Auto navigate if user does not tap within 12 seconds
    _autoNavigateTimer = Timer(const Duration(minutes: 05), () {
      if (!_tapped) {
        _navigateToLanding();
      }
    });
  }

  void _navigateToLanding() {
    setState(() => _tapped = true);
    // Toggle theme if needed
    widget.onThemeChanged?.call(widget.isDarkMode ? 'light' : 'dark');
    _tapController.forward();
  }

  @override
  void dispose() {
    _arcController.dispose();
    _tapController.dispose();
    _autoNavigateTimer?.cancel();
    super.dispose();
  }

  void _onLogoTap() {
    if (!_tapped) {
      _navigateToLanding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final arcColor = widget.isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating arcs
          AnimatedBuilder(
            animation: Listenable.merge([_arcController, _tapController]),
            builder: (_, __) {
              return Center(
                child: CustomPaint(
                  size: const Size(180, 180),
                  painter: MultiArcPainter(
                    _arcController.value * _arcSpeed.value,
                    color: arcColor,
                  ),
                ),
              );
            },
          ),
          // Glowing aura behind logo
          AnimatedBuilder(
            animation: _tapController,
            builder: (_, __) {
              return Container(
                width: 180 * _logoScale.value,
                height: 180 * _logoScale.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: arcColor.withOpacity(_glowOpacity.value),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              );
            },
          ),
          // Logo
          AnimatedBuilder(
            animation: _tapController,
            builder: (_, __) {
              return GestureDetector(
                onTap: _onLogoTap,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // App name
          Positioned(
            bottom: 50,
            child: Text(
              "MR.TECHLAB",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: arcColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MultiArcPainter extends CustomPainter {
  final double rotation;
  final Color color;

  MultiArcPainter(this.rotation, {this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcs = [
      {'radius': size.width / 2, 'width': 8.0, 'factor': 1.0, 'sweep': pi / 2},
      {'radius': size.width / 2 , 'width': 2.5, 'factor': -1.2, 'sweep': pi / 1.8},
      {'radius': size.width / 2 - 10, 'width': 5.0, 'factor': 1.5, 'sweep': pi / 1.5},
      {'radius': size.width / 2 - 10, 'width': 2.0, 'factor': -1.5, 'sweep': pi / 1.5},
    ];

    for (var arc in arcs) {
      paint.strokeWidth = arc['width'] as double;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arc['radius'] as double),
        rotation * 2 * pi * (arc['factor'] as double),
        arc['sweep'] as double,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MultiArcPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.color != color;
}
