import 'package:shared_preferences/shared_preferences.dart';

class UserSettingsService {
  static const _dailyTargetKey = 'daily_target';
  static const _smartCheckoutKey = 'smart_checkout';
  static const _dailySummaryKey = 'daily_summary';
  static const _privacyModeKey = 'privacy_mode';
  static const _themeModeKey = 'theme_mode';

  static Future<void> saveDailyTarget(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyTargetKey, hours);
  }

  static Future<int> getDailyTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyTargetKey) ?? 8;
  }

  static Future<void> saveSmartCheckout(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smartCheckoutKey, value);
  }

  static Future<bool> isSmartCheckoutEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_smartCheckoutKey) ?? true;
  }

  static Future<void> saveDailySummary(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailySummaryKey, value);
  }

  static Future<bool> isDailySummaryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dailySummaryKey) ?? true;
  }

  static Future<void> savePrivacyMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyModeKey, value);
  }

  static Future<bool> isPrivacyModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_privacyModeKey) ?? false;
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? "System";
  }
}
