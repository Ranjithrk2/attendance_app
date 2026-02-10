import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String userId;

  final DateTime checkIn;
  final DateTime? checkOut;

  final String? checkInSelfieBase64;
  final String? checkOutSelfieBase64;

  /// 📍 Location (NEW)
  final GeoPoint? checkInLocation;
  final GeoPoint? checkOutLocation;

  /// 🔁 Auto checkout flag (NEW)
  final bool autoCheckedOut;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.checkIn,
    this.checkOut,
    this.checkInSelfieBase64,
    this.checkOutSelfieBase64,
    this.checkInLocation,
    this.checkOutLocation,
    this.autoCheckedOut = false,
  });

  /// ⏱️ Total working time
  Duration get totalTime =>
      checkOut != null ? checkOut!.difference(checkIn) : Duration.zero;

  /// 📌 Status
  String get status {
    if (checkOut == null) return 'Checked In';
    if (autoCheckedOut) return 'Auto Checked Out';
    return 'Checked Out';
  }

  /// 🔄 Firestore → Model
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
      checkInLocation: data['checkInLocation'],
      checkOutLocation: data['checkOutLocation'],
      autoCheckedOut: data['autoCheckedOut'] ?? false,
    );
  }

  /// ⬆️ Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut!) : null,
      'checkInSelfieBase64': checkInSelfieBase64,
      'checkOutSelfieBase64': checkOutSelfieBase64,
      'checkInLocation': checkInLocation,
      'checkOutLocation': checkOutLocation,
      'autoCheckedOut': autoCheckedOut,
    };
  }
}