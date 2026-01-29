import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;

/// Compress image to Base64 for faster processing
Future<String> compressImageToBase64(File file) async {
  final bytes = await file.readAsBytes();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) throw Exception("Failed to decode image");

  final resized = img.copyResize(image, width: 480); // preserve aspect ratio
  final compressed = img.encodeJpg(resized, quality: 70);
  return base64Encode(compressed);
}
