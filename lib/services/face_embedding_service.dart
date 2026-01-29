import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceEmbeddingService {
  /// Extracts a face embedding from the given [Face].
  /// Returns an empty list if no landmarks are available.
  static List<double> extractEmbedding(Face? face) {
    if (face == null) return [];

    // Get all available landmarks
    final landmarks = face.landmarks.values.whereType<FaceLandmark>().toList();
    if (landmarks.isEmpty) return [];

    // Calculate center of landmarks
    double cx = 0, cy = 0;
    for (final lm in landmarks) {
      cx += lm.position.x;
      cy += lm.position.y;
    }
    cx /= landmarks.length;
    cy /= landmarks.length;

    // Create embedding as offsets from the center
    final List<double> embedding = [];
    for (final lm in landmarks) {
      embedding.add(lm.position.x - cx);
      embedding.add(lm.position.y - cy);
    }

    return embedding;
  }

  /// Calculates Euclidean distance between two embeddings
  static double calculateEuclideanDistance(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]) * (a[i] - b[i]);
    }
    return sqrt(sum); // Corrected
  }

  /// Verifies if live embedding matches master embedding with a threshold
  static bool verifyFace(List<double> master, List<double> live,
      {double threshold = 0.5}) {
    return calculateEuclideanDistance(master, live) < threshold;
  }
}
