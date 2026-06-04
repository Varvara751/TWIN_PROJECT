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
  final _confirmPass = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
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
    final confirmPassword = _confirmPass.text;

    if (password != confirmPassword) {
      _showMessage('Пароли не совпадают');
      return;
    }

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
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Регистрация.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Стрелка назад
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 30,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const Spacer(flex: 1),
                // Заголовок
                const Text(
                  'Добро пожаловать!',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),
                // Поле Имя
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'Имя',
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 16),
                // Поле Email
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      hintText: 'Адрес электронной почты',
                      border: InputBorder.none,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9@._+-]'),
                      ),
                    ],
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 16),
                // Поле Пароль
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _pass,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Пароль',
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 16),
                // Поле Повторите пароль
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _confirmPass,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Повторите пароль',
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_loading) _register();
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Кнопка Создать профиль
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A5A5A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Создать профиль',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
