import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';

import '../services/face_embedding_service.dart';

class FaceAttendanceScreen extends StatefulWidget {
  final String userId;

  const FaceAttendanceScreen({super.key, required this.userId});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen> {
  CameraController? controller;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras.first, ResolutionPreset.medium);
      await controller!.initialize();
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  /// 📍 Get current GPS location
  Future<GeoPoint> getCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return GeoPoint(position.latitude, position.longitude);
  }

  /// 👤 Get user status
  Future<String> getUserStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    return doc.data()?['status'] ?? 'active';
  }

  /// 🧠 Get master embedding
  Future<List<double>> getMasterEmbeddingFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (!doc.exists || doc.data() == null) return [];

    List<dynamic> embeddingList = doc.data()!['masterFaceEmbedding'] ?? [];
    return embeddingList.map((e) {
      if (e is int) return e.toDouble();
      if (e is double) return e;
      return 0.0;
    }).toList();
  }

  /// 🔁 Auto checkout if suspended
  Future<void> autoCheckoutIfNeeded() async {
    final snap = await FirebaseFirestore.instance
        .collection('attendance')
        .where('userId', isEqualTo: widget.userId)
        .where('checkOut', isNull: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final location = await getCurrentLocation();

      await snap.docs.first.reference.update({
        'checkOut': Timestamp.now(),
        'checkOutLocation': location,
        'autoCheckedOut': true,
      });
    }
  }

  /// 📸 Capture, verify & mark attendance
  Future<void> captureAndVerifyFace() async {
    if (controller == null || isProcessing) return;
    setState(() => isProcessing = true);

    try {
      // 🔒 Check user status
      final status = await getUserStatus();
      if (status == 'suspended') {
        await autoCheckoutIfNeeded();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account is suspended'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isProcessing = false);
        return;
      }

      final image = await controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableLandmarks: true,
        ),
      );

      final faces = await detector.processImage(inputImage);
      detector.close();

      if (faces.isEmpty) {
        throw Exception('No face detected');
      }

      final liveEmbedding =
      FaceEmbeddingService.extractEmbedding(faces.first);
      final masterEmbedding = await getMasterEmbeddingFromFirestore();

      if (!FaceEmbeddingService.verifyFace(masterEmbedding, liveEmbedding)) {
        throw Exception('Face does not match');
      }

      final location = await getCurrentLocation();

      // 🔍 Check existing open attendance
      final existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: widget.userId)
          .where('checkOut', isNull: true)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        // ✅ CHECK-IN
        await FirebaseFirestore.instance.collection('attendance').add({
          'userId': widget.userId,
          'checkIn': Timestamp.now(),
          'checkInLocation': location,
          'autoCheckedOut': false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully')),
        );
      } else {
        // ✅ CHECK-OUT
        await existing.docs.first.reference.update({
          'checkOut': Timestamp.now(),
          'checkOutLocation': location,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    setState(() => isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Face Attendance')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: CameraPreview(controller!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: captureAndVerifyFace,
            child: isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Check-In / Check-Out'),
          ),
        ],
      ),
    );
  }
}