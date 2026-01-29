import 'package:flutter/material.dart';
import 'company_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            title: 'Company Settings',
            subtitle: 'Organization name, logo, admin info',
            icon: Icons.business,
            screen: const CompanySettingsScreen(),
          ),

          _SettingsTile(
            title: 'Work Time Rules',
            subtitle: 'Office hours, late rules, overtime',
            icon: Icons.access_time,
            onTap: () {
              _comingSoon(context);
            },
          ),

          _SettingsTile(
            title: 'Data Management',
            subtitle: 'Backup, reset, export data',
            icon: Icons.storage,
            onTap: () {
              _comingSoon(context);
            },
          ),

          _SettingsTile(
            title: 'App Preferences',
            subtitle: 'Theme, notifications, behavior',
            icon: Icons.tune,
            onTap: () {
              _comingSoon(context);
            },
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🚧 Coming soon')),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? screen;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.screen,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white12,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white24,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle:
        Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing:
        const Icon(Icons.chevron_right, color: Colors.white30),
        onTap: () {
          if (screen != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screen!),
            );
          } else if (onTap != null) {
            onTap!();
          }
        },
      ),
    );
  }
}
