import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String uid;
  final String userId;
  final String name;
  final String role;
  final String? imagePath;
  final DateTime? createdAt; // ✅ added

  Member({
    required this.uid,
    required this.userId,
    required this.name,
    required this.role,
    this.imagePath,
    this.createdAt,
  });

  factory Member.fromMap(String id, Map<String, dynamic> data) {
    final rawName = data['name'];
    final rawUserId = data['userId'];
    final rawRole = data['role'];

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
      imagePath: data['profileImageBase64'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null, // ✅ safe for old users
    );
  }
}