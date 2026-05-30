import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import '../services/profile_sync_service.dart';
import 'main_screen.dart';

const allowedEmailDomains = {'mail.ru', 'gmail.com', 'yandex.ru'};

bool isAllowedRegistrationEmail(String value) {
  final email = value.trim().toLowerCase();
  final asciiOnly = email.codeUnits.every((unit) => unit <= 127);
  if (!asciiOnly) return false;

  final parts = email.split('@');
  if (parts.length != 2) return false;

  final domain = parts.last;
  final emailPattern = RegExp(
    r'^[a-z0-9._%+-]+@(mail\.ru|gmail\.com|yandex\.ru)$',
  );

  return allowedEmailDomains.contains(domain) && emailPattern.hasMatch(email);
}

String initialUsernameForRegistration(String email, String userId) {
  final prefix = email
      .split('@')
      .first
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final base = prefix.length >= 3 ? prefix : 'user';
  final suffix = userId.replaceAll('-', '').substring(0, 8);
  final maxBaseLength = 24 - suffix.length - 1;
  final baseLength = base.length < maxBaseLength ? base.length : maxBaseLength;
  return '${base.substring(0, baseLength)}_$suffix';
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _register() async {
    final email = _email.text.trim().toLowerCase();
    final password = _pass.text;

    if (!isAllowedRegistrationEmail(email)) {
      _showMessage(
        'Введите почту на английском: mail.ru, gmail.com или yandex.ru',
      );
      return;
    }

    if (password.length < 6) {
      _showMessage('Пароль должен быть минимум 6 символов');
      return;
    }

    setState(() => _loading = true);
    try {
      final existingProfile = await Supabase.instance.client
          .from(tableName)
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existingProfile != null) {
        _showMessage(
          'Профиль с такой почтой уже существует. Создать второй нельзя.',
        );
        return;
      }

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) {
        _showMessage('Не удалось создать аккаунт. Попробуйте еще раз.');
        return;
      }

      if (res.session == null) {
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } on AuthException {
          // Email confirmation may be enabled. The local profile still gets
          // saved after auth user creation; sync will continue after login.
        }
      }

      final profileData = {
        'id': user.id,
        'email': email,
        'username': initialUsernameForRegistration(email, user.id),
        'name': _name.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ProfileSyncService.instance.saveProfileAndSync(
        userId: user.id,
        profileData: profileData,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on AuthException catch (e) {
      if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit') {
        _showMessage(
          'Supabase временно ограничил отправку писем. Подождите несколько минут или отключите подтверждение email в Auth settings.',
        );
      } else if (e.message.toLowerCase().contains('already registered')) {
        _showMessage('Аккаунт с такой почтой уже зарегистрирован.');
      } else {
        _showMessage('Ошибка регистрации: ${e.message}');
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate key')) {
        _showMessage(
          'Профиль с такой почтой уже существует. Создать второй нельзя.',
        );
      } else {
        _showMessage('Ошибка базы данных: ${e.message}');
      }
    } catch (e) {
      _showMessage('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Имя'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._+-]')),
              ],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_loading) _register();
              },
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: const Text('Создать'),
                  ),
          ],
        ),
      ),
    );
  }
}
