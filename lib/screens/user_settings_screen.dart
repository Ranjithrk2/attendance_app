import 'package:flutter/material.dart';
import '../services/user_settings_service.dart';
import 'user_login_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  final String userId;

  const UserSettingsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  int dailyTarget = 8;
  bool smartCheckout = true;
  bool dailySummary = true;
  bool privacyMode = false;
  String themeMode = "System";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    dailyTarget = await UserSettingsService.getDailyTarget();
    smartCheckout = await UserSettingsService.isSmartCheckoutEnabled();
    dailySummary = await UserSettingsService.isDailySummaryEnabled();
    privacyMode = await UserSettingsService.isPrivacyModeEnabled();
    themeMode = await UserSettingsService.getThemeMode();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _title("Work"),
          _tile(
            title: "Daily Work Target",
            subtitle: "$dailyTarget hours",
            icon: Icons.timer,
            onTap: _changeDailyTarget,
          ),
          _title("Smart"),
          _switch(
            title: "Smart Check-out Reminder",
            value: smartCheckout,
            onChanged: (v) async {
              await UserSettingsService.saveSmartCheckout(v);
              setState(() => smartCheckout = v);
            },
          ),
          _switch(
            title: "Daily Work Summary",
            value: dailySummary,
            onChanged: (v) async {
              await UserSettingsService.saveDailySummary(v);
              setState(() => dailySummary = v);
            },
          ),
          _switch(
            title: "Privacy Mode",
            value: privacyMode,
            onChanged: (v) async {
              await UserSettingsService.savePrivacyMode(v);
              setState(() => privacyMode = v);
            },
          ),
          _title("Account"),
          _tile(
            title: "Logout",
            subtitle: "Sign out from this device",
            icon: Icons.logout,
            iconColor: colors.error,
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserLoginScreen(),
                ),
                    (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(letterSpacing: 1.1),
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? colors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _switch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
    );
  }

  Future<void> _changeDailyTarget() async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Daily Target"),
        children: List.generate(
          6,
              (i) => SimpleDialogOption(
            child: Text("${i + 6} hours"),
            onPressed: () => Navigator.pop(context, i + 6),
          ),
        ),
      ),
    );

    if (value != null) {
      await UserSettingsService.saveDailyTarget(value);
      setState(() => dailyTarget = value);
    }
  }
}
