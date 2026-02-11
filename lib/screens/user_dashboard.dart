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
  File? checkInImage;
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

  List<double> weeklyHours = List.filled(7, 0);
  int _todayIndex = DateTime.now().weekday - 1;

  @override
  void initState() {
    super.initState();
    sessionEmoji = (_emojis..shuffle()).first;
    _loadUserData();
    _loadWeeklyHours();
    _loadActiveCheckIn();
    _checkPin();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 12, end: 28).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  // ------------------- DATA LOADERS -------------------
  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final data = doc.data();
      if (data == null) return;
      final raw = data['masterFaceEmbedding'];
      final embedding = raw is List ? raw.map((e) => (e as num).toDouble()).toList() : null;
      if (mounted) {
        setState(() {
          _faceRegistered = embedding != null && embedding.isNotEmpty;
          firestoreUserId = data['userId'] ?? '';
          _isSuspended = data['status'] == 'suspended';
        });
      }
    } catch (_) {}
  }

  Future<void> _checkPin() async {
    final pin = await PinStorage.getPin(widget.uid);
    if (mounted) setState(() => _pinSet = pin != null);
  }

  Future<void> _loadWeeklyHours() async {
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      final snap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("userId", isEqualTo: widget.uid)
          .where("checkIn", isGreaterThanOrEqualTo: Timestamp.fromDate(monday))
          .where("checkIn", isLessThanOrEqualTo: Timestamp.fromDate(sunday))
          .get();

      List<double> tempHours = List.filled(7, 0);

      for (var doc in snap.docs) {
        final data = doc.data();
        final checkIn = (data['checkIn'] as Timestamp).toDate();
        final checkOut = data['checkOut'] != null
            ? (data['checkOut'] as Timestamp).toDate()
            : DateTime.now();
        final duration = checkOut.difference(checkIn).inMinutes / 60.0;
        final index = checkIn.weekday - 1;
        tempHours[index] += duration;
      }

      if (mounted) setState(() => weeklyHours = tempHours);
    } catch (e) {
      debugPrint("Error loading weekly hours: $e");
    }
  }

  Future<void> _loadActiveCheckIn() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("userId", isEqualTo: widget.uid)
          .where("checkOut", isNull: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final checkInTimestamp = data['checkIn'] as Timestamp?;
        final selfieBase64 = data['checkInSelfieBase64'] as String?;
        final locationData = data['location'];

        if (checkInTimestamp != null) {
          setState(() {
            checkInTime = checkInTimestamp.toDate();
            liveDuration = DateTime.now().difference(checkInTime!);
            if (selfieBase64 != null && selfieBase64.isNotEmpty) {
              checkInImage = File.fromRawPath(base64Decode(selfieBase64));
            }
            if (locationData != null) {
              _currentLocation =
              "${locationData['latitude']?.toStringAsFixed(5)}, ${locationData['longitude']?.toStringAsFixed(5)}";
            }
          });
          _startTimer();
        }
      }
    } catch (e) {
      debugPrint("Error loading active check-in: $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (checkInTime != null && mounted) {
        setState(() {
          liveDuration = DateTime.now().difference(checkInTime!);
          weeklyHours[_todayIndex] += 1 / 3600;
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

  // ----------------- CHECK-IN / CHECK-OUT -----------------
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

      setState(() {
        _currentLocation =
        "${location['latitude']?.toStringAsFixed(5)}, ${location['longitude']?.toStringAsFixed(5)}";
      });

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final data = userDoc.data();
      if (data == null) return;

      final raw = data['masterFaceEmbedding'];
      final masterEmbedding =
      raw is List ? raw.map((e) => (e as num).toDouble()).toList() : null;

      if (masterEmbedding == null || masterEmbedding.isEmpty) {
        _showSnack("Face not registered ❌");
        return;
      }

      final valid = isCheckIn
          ? await FaceVerificationService.validateCheckIn(
          masterEmbedding: masterEmbedding, selfieFile: file)
          : await FaceVerificationService.validateCheckOut(
          masterEmbedding: masterEmbedding, selfieFile: file);

      if (!valid) {
        _showSnack("Face mismatch ❌");
        return;
      }

      final storedPin = await PinStorage.getPin(widget.uid);
      if (storedPin == null) {
        _showSnack("PIN not set ❌");
        return;
      }

      String enteredPin = '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text("Enter PIN", style: TextStyle(color: Colors.white)),
          content: TextField(
            maxLength: 4,
            obscureText: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => enteredPin = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, enteredPin == storedPin),
              child: const Text("Confirm", style: TextStyle(color: Colors.white70)),
            )
          ],
        ),
      );

      if (confirmed != true) {
        _showSnack("Incorrect PIN ❌");
        return;
      }

      if (isCheckIn) {
        await FirebaseFirestore.instance.collection("attendance").add({
          "userId": widget.uid,
          "displayUserId": firestoreUserId,
          "checkIn": Timestamp.now(),
          "checkOut": null,
          "checkInSelfieBase64": selfieBase64,
          "checkInMethod": "face",
          "location": location,
        });

        setState(() {
          checkInTime = DateTime.now();
          checkInImage = file;
        });
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
        final docId = snap.docs.first.id;
        await FirebaseFirestore.instance
            .collection("attendance")
            .doc(docId)
            .update({
          "checkOut": Timestamp.now(),
          "checkOutSelfieBase64": selfieBase64,
          "checkOutMethod": "face",
          "location": location,
        });

        _timer?.cancel();
        setState(() {
          checkInTime = null;
          liveDuration = Duration.zero;
          checkInImage = null;
          sessionEmoji = (_emojis..shuffle()).first;
          _currentLocation = null;
        });
        _showSnack("Checked out ✅");
      }
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

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    final isWorking = checkInTime != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C), Color(0xFF2C2C2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        // Top row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                                      (_) => false,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Glowing avatar / emoji
                        Column(
                          children: [
                            AnimatedBuilder(
                              animation: _glowAnimation,
                              builder: (_, __) => Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isWorking
                                          ? Colors.greenAccent.withOpacity(0.8)
                                          : Colors.redAccent.withOpacity(0.8),
                                      blurRadius: _glowAnimation.value,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 65,
                                  backgroundColor: Colors.black87,
                                  backgroundImage: checkInImage != null ? FileImage(checkInImage!) : null,
                                  child: checkInImage == null
                                      ? Text(sessionEmoji,
                                      style: const TextStyle(fontSize: 56, color: Colors.white))
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            AnimatedBuilder(
                              animation: _glowAnimation,
                              builder: (_, __) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isWorking
                                          ? Colors.greenAccent.withOpacity(0.50)
                                          : Colors.redAccent.withOpacity(0.50),
                                      blurRadius: _glowAnimation.value,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isWorking ? Colors.greenAccent : Colors.redAccent,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: isWorking ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      firestoreUserId.isNotEmpty ? "ID: $firestoreUserId" : "ID: ---",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isWorking
                              ? _statusChip("SHIFT STARTED", Colors.green)
                              : _statusChip(
                              _isSuspended ? "ACCOUNT SUSPENDED" : "SHIFT ENDED",
                              _isSuspended ? Colors.redAccent : Colors.red),
                        ),

                        const SizedBox(height: 30),

                        // Live Timer
                        Text(
                          "${liveDuration.inHours.toString().padLeft(2, '0')}:"
                              "${liveDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:"
                              "${liveDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 50,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 12),



                        const SizedBox(height: 20),

                        // Modern status cards for PIN/Face/Suspension
                        if (!_pinSet || !_faceRegistered || _isSuspended)
                          Column(
                            children: [
                              if (!_pinSet) _infoCard("PIN not set", Icons.lock_outline, Colors.orangeAccent),
                              if (!_faceRegistered)
                                _infoCard("Face not registered", Icons.face_outlined, Colors.deepPurpleAccent),
                              if (_isSuspended) _infoCard("Account Suspended", Icons.block, Colors.redAccent),
                              const SizedBox(height: 20),
                            ],
                          ),

                        // Check-in / Check-out button
                        if (_faceRegistered && !_isSuspended)
                          _actionButton(
                            isWorking ? "CHECK OUT" : "CHECK IN",
                            isWorking ? Colors.redAccent : Colors.lightGreenAccent,
                            _loading ? null : _handleCheck,
                          ),

                        const SizedBox(height: 12),

                        // Face Register if not registered
                        if (!_faceRegistered)
                          _actionButton(
                            "REGISTER FACE",
                            Colors.orangeAccent,
                                () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => FaceRegisterScreen(userId: widget.uid)),
                              );
                              _loadUserData();
                              _checkPin();
                            },
                          ),

                        const SizedBox(height: 12),

                        // Attendance History
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const UserAttendanceHistoryScreen()),
                            );
                          },
                          child: const Text(
                            "Attendance History",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      key: ValueKey(text),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoCard(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionButton(String text, Color color, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: SizedBox(
        height: 55,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            side: BorderSide(color: color, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
            text,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ),
    );
  }
}
