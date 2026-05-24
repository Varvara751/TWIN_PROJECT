import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'interests_edit_screen.dart';

const String TABLE_NAME = 'profil';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dzizzuiguphenpsjlpwj.supabase.co',
    anonKey: 'sb_publishable_COxWwXNYOJCK378rC_nSXA_x8tOBP9u',
  );

  runApp(const MyApp());
}

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

//Проверка авторизации
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null ? const MainScreen() : const WelcomeScreen();
  }
}


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Главный2.png'),
            fit: BoxFit.cover,
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
                          right:
                              20, 
                          top: 120,
                          child: Container(height: 2, color: Colors.black),
                        ),

                        
                        Positioned(
                          left: 20,
                          top: 132,
                          child: const Text(
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
                        // Создать профиль
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

                        // Войти
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

                  //  НИЖНИЙ ТЕКСТ
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 40,
                      left: 30,
                      right: 30,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Продолжая ты принимаешь условия',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Соглашение и Конфиденциальности',
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
                          'Мы используем Рекомендательные технологии',
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


// ЭКРАН РЕГИСТРАЦИИ
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

  Future<void> _register() async {
    
    final email = _email.text.trim();
    final password = _pass.text;

    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Введите Email')));
      return;
    }

    if (password.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Пароль минимум 6 символов')),
      );
      return;
    }
    
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (res.user != null) {
        await Supabase.instance.client.from(TABLE_NAME).insert({
          'id': res.user!.id,
          'email': _email.text.trim(),
          'name': _name.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
            ),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
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


// ЭКРАН ВХОДА

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  Future<void> _login() async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false, // Удаляем все предыдущие экраны
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
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
            ),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('Войти')),
          ],
        ),
      ),
    );
  }
}


//  ГЛАВНЫЙ ЭКРАН С НИЖНЕЙ НАВИГАЦИЕЙ

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    FavoritesScreen(),
    MessengerScreen(),
    SettingsScreen(),
    ViewProfileScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Избранное',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Мессенджер',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Настройки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}


// ЭКРАНЫ-ЗАГЛУШКИ

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('🏠 Главная'));
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('❤️ Избранное'));
}

class MessengerScreen extends StatelessWidget {
  const MessengerScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('💬 Мессенджер'));
}


// ЭКРАН НАСТРОЕК

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    // Показываем диалог подтверждения
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
    // Показываем диалог подтверждения
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
          // Удаляем профиль из таблицы
          await Supabase.instance.client
              .from('profil')
              .delete()
              .eq('id', user.id);

          // Выходим из аккаунта
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
              // Логотип
              const Text(
                'TWIN',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Times New Roman',
                ),
              ),
              const SizedBox(height: 40),

              // Кнопка "Выйти из аккаунта"
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: Colors.black),
                  label: const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Кнопка "Удалить анкету"
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _deleteAccount(context),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Удалить анкету',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const Spacer(),

              // Информация о пользователе 
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


// ЭКРАН ПРОСМОТРА ПРОФИЛЯ

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from(TABLE_NAME)
          .select()
          .eq('id', user.id)
          .single();
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null)
      return const Scaffold(body: Center(child: Text('Профиль не найден')));

    final name = _data!['name'] ?? 'Имя';
    final surname = _data!['surname'] ?? ''; // Добавили фамилию
    final age = _data!['age']?.toString() ?? '';
    final city = _data!['city'] ?? 'Город';
    final avatar = _data!['avatar_url'];
    final stats = {'Подписчиков': 129, 'Подписок': 36, 'Лайков': 56};

    // Формируем полное имя
    final fullName = surname.isNotEmpty ? '$name $surname' : name;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE8C8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Профиль', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            child: const Text(
              'Редактировать',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Аватарка
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 10),
            // Имя с фамилией и возрастом
            Text(
              '$fullName${age.isNotEmpty ? ', $age' : ''}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('г. $city', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            // Статистика
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: stats.entries
                  .map(
                    (e) => Column(
                      children: [
                        Text(
                          '${e.value}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink,
                          ),
                        ),
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            // Вкладки
            TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              tabs: const [
                Tab(text: 'О себе'),
                Tab(text: 'Фотографии'),
              ],
            ),
            SizedBox(
              height: 200, 
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Вкладка "О себе"
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _data!['bio'] ?? 'Пока ничего не написано...',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  // Вкладка "Фотографии"
                  GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.all(4),
                    children: List.generate(
                      6,
                      (i) => Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          color: Colors.grey.shade300,
                          child: Center(child: Text('Фото $i')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            //  СЕКЦИЯ ИНТЕРЕСОВ 
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Мои интересы',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InterestsEditScreen(),
                            ),
                          ).then((_) => _loadProfile());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_data!['interests'] ?? [])
                        .map<Widget>(
                          (interest) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              interest.toString(),
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),  
          ],
        ),
      ),
    );
  }
}


//  ЭКРАН РЕДАКТИРОВАНИЯ ПРОФИЛЯ 

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _bio = TextEditingController();

  File? _avatarFile;
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from(TABLE_NAME)
        .select()
        .eq('id', user.id)
        .single();

    if (!mounted) return;
    setState(() {
      _name.text = res['name'] ?? '';
      _surname.text = res['surname'] ?? '';
      _age.text = res['age']?.toString() ?? '';
      _city.text = res['city'] ?? '';
      _country.text = res['country'] ?? '';
      _bio.text = res['bio'] ?? '';
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final fileSize = await File(image.path).length();
      const maxFileSize = 2 * 1024 * 1024;
      if (fileSize > maxFileSize) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл слишком большой! Выберите фото до 2 МБ.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final targetPath = image.path.replaceAll('.jpg', '_compressed.jpg');
        final result = await FlutterImageCompress.compressAndGetFile(
          image.path,
          targetPath,
          minWidth: 800,
          minHeight: 800,
          quality: 80,
          format: CompressFormat.jpeg,
        );

        if (result != null && mounted) {
          setState(() => _avatarFile = File(result.path));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка обработки фото: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      String? avatarUrl;

      if (_avatarFile != null) {
        final fileName =
            'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

        await Supabase.instance.client.storage
            .from('avatars')
            .upload(
              fileName,
              _avatarFile!,
              fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
            );

        avatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
      }

      await Supabase.instance.client.from(TABLE_NAME).upsert({
        'id': user.id,
        'email': user.email,
        'name': _name.text,
        'surname': _surname.text,
        'age': int.tryParse(_age.text),
        'city': _city.text,
        'country': _country.text,
        'bio': _bio.text,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'created_at': DateTime.now().toIso8601String(), 
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator()
                : const Text('Сохранить'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _avatarFile != null
                      ? FileImage(_avatarFile!)
                      : null,
                  child: _avatarFile == null
                      ? const Icon(Icons.camera_alt, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildField('Имя', _name),
              _buildField('Фамилия', _surname),
              _buildField('Возраст', _age, isNumber: true),
              _buildField('Город', _city),
              _buildField('Страна', _country),
              _buildField('О себе', _bio, maxLines: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
