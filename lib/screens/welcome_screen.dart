import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE0E5), Color(0xFFFFF4E8)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 170,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 20,
                          top: 35,
                          child: const Text(
                            'TWIN',
                            style: TextStyle(
                              fontFamily: 'Rosarivo',
                              fontSize: 70,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                              height: 1.0,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 285,
                          top: 70,
                          child: const Icon(
                            Icons.favorite_outline,
                            size: 32,
                            color: Colors.black,
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          top: 120,
                          child: Container(height: 2, color: Colors.black),
                        ),
                        const Positioned(
                          left: 20,
                          top: 132,
                          child: Text(
                            'Найди свою идеальную пару',
                            style: TextStyle(
                              fontFamily: 'Rosarivo',
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF5A5A5A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Создать профиль',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide.none,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Войти',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 40,
                      left: 30,
                      right: 30,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Продолжая, ты принимаешь условия',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Соглашение и конфиденциальность',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Мы используем рекомендательные технологии',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Служба поддержки',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
