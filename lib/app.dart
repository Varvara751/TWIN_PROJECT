import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TWIN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.pink, fontFamily: 'Roboto'),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null ? const MainScreen() : const WelcomeScreen();
  }
}
