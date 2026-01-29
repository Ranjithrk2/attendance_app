import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_embedding_service.dart';

class FaceVerificationService {
  static double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) sum += pow(a[i] - b[i], 2);
    return sqrt(sum);
  }

  static List<double> _normalize(List<double> emb) {
    final norm = sqrt(emb.fold(0, (sum, e) => sum + e * e));
    if (norm == 0) return emb;
    return emb.map((e) => e / norm).toList();
  }

  static const double _THRESHOLD = 0.6;

  static Future<bool> validateCheckIn({
    required List<double> masterEmbedding,
    required File selfieFile,
  }) async {
    return _validateFace(masterEmbedding: masterEmbedding, selfieFile: selfieFile, type: "Check-in");
  }

  static Future<bool> validateCheckOut({
    required List<double> masterEmbedding,
    required File selfieFile,
  }) async {
    return _validateFace(masterEmbedding: masterEmbedding, selfieFile: selfieFile, type: "Check-out");
  }

  static Future<bool> _validateFace({
    required List<double> masterEmbedding,
    required File selfieFile,
    required String type,
  }) async {
    try {
      final detector = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true, enableContours: true));
      final faces = await detector.processImage(InputImage.fromFile(selfieFile));
      detector.close();
      if (faces.isEmpty) return false;

      final liveEmbedding = FaceEmbeddingService.extractEmbedding(faces.first);
      if (liveEmbedding.isEmpty || liveEmbedding.length != masterEmbedding.length) return false;

      final distance = _euclideanDistance(_normalize(masterEmbedding), _normalize(liveEmbedding));
      print("$type Distance: $distance");
      return distance < _THRESHOLD;
    } catch (e) {
      print("$type verification error: $e");
      return false;
    }
  }
}