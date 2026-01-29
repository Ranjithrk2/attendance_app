import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String userId;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? checkInSelfieBase64;
  final String? checkOutSelfieBase64;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.checkIn,
    this.checkOut,
    this.checkInSelfieBase64,
    this.checkOutSelfieBase64,
  });

  /// Total working time
  Duration get totalTime =>
      checkOut != null ? checkOut!.difference(checkIn) : Duration.zero;

  /// Status
  String get status => checkOut == null ? 'Checked In' : 'Checked Out';

  /// Firestore → Model
  factory AttendanceRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      throw Exception('Invalid date type: ${value.runtimeType}');
    }

    return AttendanceRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      checkIn: parseDate(data['checkIn']),
      checkOut:
      data['checkOut'] != null ? parseDate(data['checkOut']) : null,
      checkInSelfieBase64: data['checkInSelfieBase64'],
      checkOutSelfieBase64: data['checkOutSelfieBase64'],
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut!) : null,
      'checkInSelfieBase64': checkInSelfieBase64,
      'checkOutSelfieBase64': checkOutSelfieBase64,
    };
  }
}
