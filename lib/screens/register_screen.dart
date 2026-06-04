import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_sync_service.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
          'Это действие нельзя отменить. Ваш аккаунт, анкета и данные будут удалены навсегда.',
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
          await Supabase.instance.client.functions.invoke('delete-account');
          await ProfileSyncService.instance.clearUserData(user.id);
          await Supabase.instance.client.auth.signOut();
        }

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      } on FunctionException catch (e) {
        if (!context.mounted) return;
        final message = e.status == 404
            ? 'Функция удаления аккаунта не настроена на сервере'
            : 'Ошибка при удалении аккаунта';
        _showMessage(context, message);
      } catch (_) {
        if (!context.mounted) return;
        _showMessage(context, 'Ошибка при удалении аккаунта');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        // 🔽 ФОНОВОЕ ИЗОБРАЖЕНИЕ — замените путь на свой файл!
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/images/Настройки.png',
            ), // ← ЗАМЕНИТЕ НА СВОЙ ФАЙЛ
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Заголовок "Настройки"
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 16),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              // TWIN — по центру
              const Center(
                child: Text(
                  'TWIN',
                  style: TextStyle(
                    fontFamily: 'Rosarivo',
                    fontSize: 48,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
              // Линия под TWIN — тоже по центру
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 8,
                ),
                child: Container(height: 1, color: Colors.black),
              ),
              const SizedBox(height: 40),
              // Кнопки
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Выйти из аккаунта
                    _SettingsButton(
                      icon: Icons.logout,
                      iconColor: Colors.black,
                      label: 'Выйти из аккаунта',
                      labelColor: Colors.black,
                      onPressed: () => _logout(context),
                    ),
                    const SizedBox(height: 15),
                    // Удалить анкету
                    _SettingsButton(
                      icon: Icons.delete_outline,
                      iconColor: Colors.red,
                      label: 'Удалить анкету',
                      labelColor: Colors.red,
                      onPressed: () => _deleteAccount(context),
                    ),
                  ],
                ),
              ),
              const Spacer(),
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
  final Color labelColor;
  final String label;
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
        icon: Icon(icon, color: iconColor, size: 24),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Onest',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: labelColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }
}
