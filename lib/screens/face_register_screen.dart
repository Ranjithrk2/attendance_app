import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_embedding_service.dart';
import '../services/pin_storage.dart';

class FaceRegisterScreen extends StatefulWidget {
  final String userId;

  const FaceRegisterScreen({super.key, required this.userId});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  CameraController? _cameraController;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      if (mounted) setState(() {});

      // Automatically capture after 1 second
      Future.delayed(const Duration(seconds: 1), _captureAndRegisterFace);
    } catch (e) {
      _showMessage('Camera init failed: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndRegisterFace() async {
    if (_cameraController == null || isProcessing) return;

    setState(() => isProcessing = true);

    try {
      // 1️⃣ Capture image
      final picture = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);

      // 2️⃣ Detect face
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(enableLandmarks: true, enableContours: true),
      );
      final faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      if (faces.isEmpty) {
        _showMessage('No face detected. Try again.');
        setState(() => isProcessing = false);
        return;
      }

      // 3️⃣ Extract embedding
      final embedding = FaceEmbeddingService.extractEmbedding(faces.first);
      if (embedding.isEmpty) {
        _showMessage('Failed to extract face data.');
        setState(() => isProcessing = false);
        return;
      }

      // 4️⃣ Save embedding to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
        'masterFaceEmbedding': embedding,
        'faceRegistered': true,
      }, SetOptions(merge: true));

      _showMessage('Face saved successfully ✅');

      // 5️⃣ Prompt to set PIN
      await _promptSetPin();

      // 6️⃣ Return captured image to previous screen
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pop(context, File(picture.path));
        });
      }
    } catch (e) {
      _showMessage('Error: $e');
      setState(() => isProcessing = false);
    }
  }

  Future<void> _promptSetPin() async {
    String pin = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Set a 4-digit PIN'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
          onChanged: (v) => pin = v,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (pin.length != 4) return;
              await PinStorage.savePin(widget.userId, pin);
              Navigator.pop(context);
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
    _showMessage('PIN saved ✅');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraPreview(_cameraController!),
          if (isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}