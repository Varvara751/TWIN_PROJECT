import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InterestsEditScreen extends StatefulWidget {
  const InterestsEditScreen({super.key});

  @override
  State<InterestsEditScreen> createState() => _InterestsEditScreenState();
}

class _InterestsEditScreenState extends State<InterestsEditScreen> {
  // Все доступные интересы
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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  // Загружаем текущие интересы пользователя
  Future<void> _loadInterests() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('profil')
        .select('interests')
        .eq('id', user.id)
        .single();

    if (mounted) {
      setState(() {
        _selectedInterests =
            (response['interests'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      });
    }
  }

  // Переключение интереса
  void _toggle(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  // Сохранение в базу
  Future<void> _save() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('profil')
          .update({'interests': _selectedInterests})
          .eq('id', user.id);

      if (!mounted) return;
      Navigator.pop(context); // Возвращаемся на профиль
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
      backgroundColor: const Color(0xFFFDECD0), // Бежевый фон как на макете
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Профиль', style: TextStyle(color: Colors.black87)),
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
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выбери то, чем ты увлекаешься:',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 колонки
                  childAspectRatio: 3.0, // Пропорции кнопок
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _allInterests.length,
                itemBuilder: (context, index) {
                  final interest = _allInterests[index];
                  final isSelected = _selectedInterests.contains(interest);

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
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          interest,
                          style: TextStyle(
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
    );
  }
}
