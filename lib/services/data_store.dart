import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member.dart';
import '../models/attendance_record.dart';

class DataStore {
  static List<Member> members = [];
  static List<AttendanceRecord> attendanceRecords = [];

  /// ================= FETCH MEMBERS =================
  static Future<void> fetchMembers() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('users').get();

      members = snapshot.docs.map((doc) {
        final data = doc.data();

        return Member(
          uid: doc.id,
          userId: data['userId'] ?? doc.id,
          name: data['name'] ?? 'Unnamed',
          role: data['role'] ?? 'User',
          imagePath: data['profileImageBase64'], // Base64 string
        );
      }).toList();
    } catch (e) {
      throw Exception('Error fetching members: $e');
    }
  }

  /// ================= FETCH ATTENDANCE =================
  static Future<void> fetchAttendanceRecords() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('attendance').get();

      attendanceRecords = snapshot.docs
          .map((doc) => AttendanceRecord.fromDoc(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching attendance records: $e');
    }
  }

  /// ================= LOAD EVERYTHING =================
  static Future<void> loadAllData() async {
    await Future.wait([
      fetchMembers(),
      fetchAttendanceRecords(),
    ]);
  }

  /// ================= FILTER BY MEMBER =================
  static List<AttendanceRecord> recordsForMember(String userId) {
    return attendanceRecords
        .where((r) => r.userId == userId)
        .toList();
  }
}
