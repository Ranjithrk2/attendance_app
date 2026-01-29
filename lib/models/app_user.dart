class AppUser {
  final String id;
  final String name;        // userId or display name
  final String role;        // admin / user

  // 🔐 AUTH RELATED
  final bool firstLogin;    // force change password on first login

  // 📸 ATTENDANCE RELATED
  String? selfiePath;
  DateTime? lastAttendanceTime;
  bool isPresent;

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.firstLogin,
    this.selfiePath,
    this.lastAttendanceTime,
    this.isPresent = false,
  });
}
