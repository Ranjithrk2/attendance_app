import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String uid;
  final String userId;
  final String name;
  final String role;
  final String status; // ✅ ADD THIS
  final String? imagePath;
  final DateTime? createdAt;

  Member({
    required this.uid,
    required this.userId,
    required this.name,
    required this.role,
    required this.status, // ✅ REQUIRED
    this.imagePath,
    this.createdAt,
  });

  factory Member.fromMap(String id, Map<String, dynamic> data) {
    final rawName = data['name'];
    final rawUserId = data['userId'];
    final rawRole = data['role'];
    final rawStatus = data['status'];

    return Member(
      uid: (data['uid'] ?? id).toString(),

      userId: (rawUserId != null && rawUserId.toString().trim().isNotEmpty)
          ? rawUserId.toString()
          : '—',

      name: (rawName != null && rawName.toString().trim().isNotEmpty)
          ? rawName.toString()
          : 'Unknown User',

      role: (rawRole != null && rawRole.toString().trim().isNotEmpty)
          ? rawRole.toString()
          : 'Employee',

      status: (rawStatus != null && rawStatus.toString().trim().isNotEmpty)
          ? rawStatus.toString()
          : 'suspended', // ✅ SAFE DEFAULT

      imagePath: data['profileImageBase64'],

      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}