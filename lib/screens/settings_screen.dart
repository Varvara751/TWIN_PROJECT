import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы будете перенаправлены на экран входа.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Удалить анкету?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Это действие нельзя отменить. Ваша анкета будет удалена навсегда.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from(tableName)
              .delete()
              .eq('id', user.id);
          await Supabase.instance.client.auth.signOut();
        }

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE0E5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Настройки', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'TWIN',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Times New Roman',
                ),
              ),
              const SizedBox(height: 40),
              _SettingsButton(
                icon: Icons.logout,
                iconColor: Colors.black,
                label: 'Выйти из аккаунта',
                labelColor: Colors.black,
                onPressed: () => _logout(context),
              ),
              const SizedBox(height: 15),
              _SettingsButton(
                icon: Icons.delete_outline,
                iconColor: Colors.red,
                label: 'Удалить анкету',
                labelColor: Colors.red,
                onPressed: () => _deleteAccount(context),
              ),
              const Spacer(),
              if (user != null)
                Text(
                  user.email ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
        label: Text(label, style: TextStyle(fontSize: 16, color: labelColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: labelColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
