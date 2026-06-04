import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import '../screens/main_screen.dart';

const loginErrorMessage =
    'Ошибка: профиль не существует или вы неправильно ввели почту/пароль';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    final email = _email.text.trim().toLowerCase();
    final password = _pass.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(loginErrorMessage);
      return;
    }

    setState(() => _loading = true);
    try {
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      final userId = authResponse.user?.id;

      if (userId == null) {
        await Supabase.instance.client.auth.signOut();
        _showMessage(loginErrorMessage);
        return;
      }

      final profile = await Supabase.instance.client
          .from(tableName)
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        await Supabase.instance.client.auth.signOut();
        _showMessage(loginErrorMessage);
        return;
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
      );
    } on AuthException {
      _showMessage(loginErrorMessage);
    } catch (_) {
      _showMessage(loginErrorMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Вход.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // 🔽 Стрелка назад
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
                // Заголовок большими буквами со шрифтом Onest
                const Text(
                  'Войти',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),
                // Поле Email
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
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
                      suffixIcon: Icon(Icons.visibility, color: Colors.grey),
                    ),
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
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_loading) _login();
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Кнопка Войти
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
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
                            'Войти',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                // Забыли пароль
                TextButton(
                  onPressed: () {
                    // TODO: Добавить восстановление пароля
                  },
                  child: const Text(
                    'Я не помню пароль',
                    style: TextStyle(color: Color(0xFF8B7FD4), fontSize: 14),
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
