import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import 'main_screen.dart';

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
      appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_loading) _login();
              },
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _login, child: const Text('Войти')),
          ],
        ),
      ),
    );
  }
}
