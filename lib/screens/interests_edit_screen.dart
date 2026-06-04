import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import '../services/profile_sync_service.dart';

class InterestsEditScreen extends StatefulWidget {
  const InterestsEditScreen({super.key});

  @override
  State<InterestsEditScreen> createState() => _InterestsEditScreenState();
}

class _InterestsEditScreenState extends State<InterestsEditScreen> {
  final List<String> _allInterests = [
    'Спорт',
    'Музыка',
    'Танцы',
    'Книги',
    'Рыбалка',
    'Путешествия',
    'Кино',
    'Выпечка',
    'Йога',
    'Фотография',
    'Рисование',
    'Блог',
    'Садоводство',
    'Горы',
    'Лыжи',
    'Наука',
    'Стендап',
    'Скрапбукинг',
    'Таро',
    'Вязание',
    'Киберспорт',
    'Охота',
    'Ремонт',
  ];

  List<String> _selectedInterests = [];
  Map<String, dynamic>? _profile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final localProfile = await ProfileSyncService.instance.getLocalProfile(
      user.id,
    );
    final response =
        localProfile ??
        await Supabase.instance.client
            .from(tableName)
            .select()
            .eq('id', user.id)
            .single();

    if (mounted) {
      setState(() {
        _profile = Map<String, dynamic>.from(response);
        _selectedInterests =
            (response['interests'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      });
    }
  }

  void _toggle(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = Map<String, dynamic>.from(_profile ?? {});
      profile['id'] = user.id;
      profile['email'] = user.email;
      profile['interests'] = _selectedInterests;
      profile['updated_at'] = DateTime.now().toIso8601String();
      await ProfileSyncService.instance.saveProfileAndSync(
        userId: user.id,
        profileData: profile,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // ← Прозрачный фон
      body: Container(
        // 🔽 ФОНОВОЕ ИЗОБРАЖЕНИЕ — замените путь на свой файл!
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Осебе.png'), // ← ВАШ ПУТЬ К ФОНУ
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.black87,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Профиль',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Сохранить',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
              // Контент
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Выбери то, чем ты увлекаешься:',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 3.0,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: _allInterests.length,
                          itemBuilder: (context, index) {
                            final interest = _allInterests[index];
                            final isSelected = _selectedInterests.contains(
                              interest,
                            );

                            return GestureDetector(
                              onTap: () => _toggle(interest),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.orange.shade100
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.black12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    interest,
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      color: isSelected
                                          ? Colors.orange.shade900
                                          : Colors.black87,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
