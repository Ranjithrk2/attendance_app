import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

import '../services/face_verification_service.dart';
import '../services/pin_storage.dart';
import '../services/location_service.dart';
import 'selfie_camera_screen.dart';
import 'user_attendance_history_screen.dart';
import 'face_register_screen.dart';
import 'user_login_screen.dart';

class UserDashboard extends StatefulWidget {
  final String uid;
  const UserDashboard({super.key, required this.uid});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard>
    with SingleTickerProviderStateMixin {
  DateTime? checkInTime;
  Duration liveDuration = Duration.zero;
  Timer? _timer;

  MemoryImage? checkInImage; // ✅ FIXED (was File)
  bool _loading = false;
  bool _faceRegistered = false;
  bool _pinSet = false;
  String firestoreUserId = "";
  bool _isSuspended = false;
  String sessionEmoji = "😎";
  String? _currentLocation;

  final List<String> _emojis = [
    "😎","🎯","🧠","🤠","😁","👻","☠️","🧟‍♂️","🤑",
    "🥴","🗿","🌞","😬","🧝‍♀️","👸","👹","🦸‍♀️","👨‍🦱","🥷","🧐",
  ];

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    sessionEmoji = (_emojis..shuffle()).first;

    _loadUserData();
    _loadActiveCheckIn();
    _checkPin();

    _glowController =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 12, end: 28).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  // ---------------- LOAD USER ----------------

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    final raw = data['masterFaceEmbedding'];
    final embedding = raw is List
        ? raw.map((e) => (e as num).toDouble()).toList()
        : null;

    if (!mounted) return;

    setState(() {
      _faceRegistered = embedding != null && embedding.isNotEmpty;
      firestoreUserId = data['userId'] ?? '';
      _isSuspended = data['status'] == 'suspended';
    });
  }

  Future<void> _checkPin() async {
    final pin = await PinStorage.getPin(widget.uid);
    if (mounted) setState(() => _pinSet = pin != null);
  }

  // ---------------- LOAD ACTIVE CHECKIN ----------------

  Future<void> _loadActiveCheckIn() async {
    final snap = await FirebaseFirestore.instance
        .collection("attendance")
        .where("userId", isEqualTo: widget.uid)
        .where("checkOut", isNull: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    final data = snap.docs.first.data();
    final checkInTimestamp = data['checkIn'] as Timestamp?;
    final selfieBase64 = data['checkInSelfieBase64'] as String?;
    final locationData = data['location'];

    if (checkInTimestamp == null) return;

    checkInTime = checkInTimestamp.toDate();
    liveDuration = DateTime.now().difference(checkInTime!);

    // ✅ FIX SELFIE
    if (selfieBase64 != null && selfieBase64.isNotEmpty) {
      final bytes = base64Decode(selfieBase64);
      checkInImage = MemoryImage(bytes);
    }

    // ✅ FIX LOCATION
    if (locationData != null &&
        locationData['latitude'] != null &&
        locationData['longitude'] != null) {
      final lat = (locationData['latitude'] as num).toDouble();
      final lng = (locationData['longitude'] as num).toDouble();
      _currentLocation =
      "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
    } else {
      _currentLocation = "Location unavailable";
    }

    if (mounted) setState(() {});
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (checkInTime != null && mounted) {
        setState(() {
          liveDuration = DateTime.now().difference(checkInTime!);
        });
      }
    });
  }

  Future<String> _compressImageBase64(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return base64Encode(bytes);

    final resized = img.copyResize(image, width: 800);
    final jpg = img.encodeJpg(resized, quality: 70);
    return base64Encode(jpg);
  }

  // ---------------- CHECK IN / OUT ----------------

  Future<void> _handleCheck() async {
    try {
      setState(() => _loading = true);

      if (_isSuspended) {
        _showSnack("Your account is suspended ❌");
        return;
      }

      if (!_faceRegistered) {
        _showSnack("Face not registered ❌");
        return;
      }

      if (!_pinSet) {
        _showSnack("PIN not set ❌");
        return;
      }

      final isCheckIn = checkInTime == null;

      final File? file = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelfieCameraScreen(isCheckIn: isCheckIn),
        ),
      );

      if (file == null) return;

      final selfieBase64 = await _compressImageBase64(file);
      final location = await LocationService.getCurrentLocation();

      String formattedLocation = "Location unavailable";

      if (location['latitude'] != null &&
          location['longitude'] != null) {
        final lat = (location['latitude'] as num).toDouble();
        final lng = (location['longitude'] as num).toDouble();
        formattedLocation =
        "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      }

      final bytes = await file.readAsBytes();
      checkInImage = MemoryImage(bytes);

      if (isCheckIn) {
        await FirebaseFirestore.instance.collection("attendance").add({
          "userId": widget.uid,
          "displayUserId": firestoreUserId,
          "checkIn": Timestamp.now(),
          "checkOut": null,
          "checkInSelfieBase64": selfieBase64,
          "location": location,
        });

        checkInTime = DateTime.now();
        _currentLocation = formattedLocation;

        _startTimer();
        _showSnack("Checked in ✅");
      } else {
        final snap = await FirebaseFirestore.instance
            .collection("attendance")
            .where("userId", isEqualTo: widget.uid)
            .where("checkOut", isNull: true)
            .limit(1)
            .get();

        if (snap.docs.isEmpty) {
          _showSnack("No active check-in found ❌");
          return;
        }

        await FirebaseFirestore.instance
            .collection("attendance")
            .doc(snap.docs.first.id)
            .update({
          "checkOut": Timestamp.now(),
          "checkOutSelfieBase64": selfieBase64,
          "location": location,
        });

        _timer?.cancel();

        checkInTime = null;
        checkInImage = null;
        liveDuration = Duration.zero;
        _currentLocation = null;

        _showSnack("Checked out ✅");
      }

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isWorking = checkInTime != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 30),

              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (_, __) => CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.black87,
                  backgroundImage: checkInImage,
                  child: checkInImage == null
                      ? Text(sessionEmoji,
                      style: const TextStyle(fontSize: 56))
                      : null,
                ),
              ),

              const SizedBox(height: 40),

              Text(
                "${liveDuration.inHours.toString().padLeft(2, '0')}:"
                    "${liveDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:"
                    "${liveDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                    color: Colors.white, fontSize: 40),
              ),

              const SizedBox(height: 10),

              if (_currentLocation != null)
                Text(
                  "📍 $_currentLocation",
                  style: const TextStyle(color: Colors.white70),
                ),

              const Spacer(),

              ElevatedButton(
                onPressed: _loading ? null : _handleCheck,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(isWorking ? "CHECK OUT" : "CHECK IN"),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}