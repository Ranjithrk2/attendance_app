import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class SelfieCameraScreen extends StatefulWidget {
  final bool isCheckIn;
  const SelfieCameraScreen({super.key, required this.isCheckIn});

  @override
  State<SelfieCameraScreen> createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<SelfieCameraScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _processing = false;
  late FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
    );
    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    setState(() => _ready = true);
  }

  Future<void> _captureFace() async {
    if (_processing) return;
    _processing = true;

    try {
      final file = await _controller!.takePicture();
      // Optional: detect face before returning
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        Navigator.pop(context, File(file.path)); // return captured image
      } else {
        // No face detected, show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No face detected. Try again.")),
        );
      }
    } catch (e) {
      print("Error capturing face: $e");
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: const BackButton(),
        title: const Text("Capture Your Face"),
        centerTitle: true,
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 40,
            left: 60,
            right: 60,
            child: ElevatedButton(
              onPressed: _captureFace,
              child: const Text("Capture"),
            ),
          ),
        ],
      ),
    );
  }
}
