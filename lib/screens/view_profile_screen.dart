import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import 'edit_profile_screen.dart';
import 'interests_edit_screen.dart';

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from(tableName)
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return const Scaffold(body: Center(child: Text('Профиль не найден')));
    }

    final name = _data!['name'] ?? 'Имя';
    final surname = _data!['surname'] ?? '';
    final age = _data!['age']?.toString() ?? '';
    final city = _data!['city'] ?? 'Город';
    final avatar = _data!['avatar_url'];
    final stats = {'Подписчиков': 129, 'Подписок': 36, 'Лайков': 56};
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
            ).then((_) => _loadProfile()),
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
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              '$fullName${age.isNotEmpty ? ', $age' : ''}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('г. $city', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _data!['bio'] ?? 'Пока ничего не написано...',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  color: Colors.black.withValues(alpha: 0.05),
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
