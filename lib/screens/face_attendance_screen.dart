import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_embedding_service.dart';

class FaceAttendanceScreen extends StatefulWidget {
  final String userId; // Current logged-in user
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

  /// Fetch master face embedding from Firestore safely
  Future<List<double>> getMasterEmbeddingFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (!doc.exists || doc.data() == null) return [];

    List<dynamic> embeddingList = doc.data()!['masterFaceEmbedding'] ?? [];

    // Safely convert to double
    return embeddingList.map((e) {
      if (e == null) return 0.0;
      if (e is int) return e.toDouble();
      if (e is double) return e;
      if (e is String) return double.tryParse(e) ?? 0.0;
      return 0.0;
    }).toList();
  }

  /// Capture and verify face
  Future<void> captureAndVerifyFace() async {
    if (controller == null || isProcessing) return;
    setState(() => isProcessing = true);

    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face detected!')),
        );
        setState(() => isProcessing = false);
        return;
      }

      // Extract live embedding
      final liveEmbedding = FaceEmbeddingService.extractEmbedding(faces.first);

      // Get master embedding
      final masterEmbedding = await getMasterEmbeddingFromFirestore();

      // Verify face
      if (FaceEmbeddingService.verifyFace(masterEmbedding, liveEmbedding)) {
        // ✅ Mark attendance
        await FirebaseFirestore.instance
            .collection('attendance')
            .doc('${widget.userId}_${DateTime.now().toIso8601String()}')
            .set({
          'userId': widget.userId,
          'timestamp': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance marked!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face does not match!')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
