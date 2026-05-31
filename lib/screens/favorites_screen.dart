import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/social_service.dart';
import '../widgets/username_badge.dart';
import 'view_profile_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _search = TextEditingController();
  final _social = SocialService.instance;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  int _searchRun = 0;

  String? get _userId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _search.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final followers = await _social.followers(userId);
      final following = await _social.following(userId);
      if (mounted) {
        setState(() {
          _followers = followers;
          _following = following;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSearchChanged() async {
    final query = _search.text.trim();
    final run = ++_searchRun;
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
      return;
    }
    setState(() => _searching = true);
    final results = await _social.searchProfiles(query);
    if (!mounted || run != _searchRun) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> profiles) {
    final query = _search.text.trim().toLowerCase().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    if (query.isEmpty) return profiles;
    return profiles.where((profile) {
      return ['username', 'name', 'surname'].any(
        (key) => (profile[key] ?? '').toString().toLowerCase().contains(query),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Избранное'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.pink,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.pink,
          tabs: const [
            Tab(text: 'Подписчики'),
            Tab(text: 'Подписки'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Поиск по @username',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _search.text.trim().isNotEmpty
                ? _searching
                      ? const Center(child: CircularProgressIndicator())
                      : _ProfileList(
                          profiles: _searchResults,
                          emptyText:
                              'РџРѕР»СЊР·РѕРІР°С‚РµР»Рё РЅРµ РЅР°Р№РґРµРЅС‹',
                        )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ProfileList(
                          profiles: _filter(_followers),
                          emptyText: 'Подписчиков пока нет',
                        ),
                        _ProfileList(
                          profiles: _filter(_following),
                          emptyText: 'Подписок пока нет',
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({required this.profiles, required this.emptyText});

  final List<Map<String, dynamic>> profiles;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          Center(child: Text(emptyText)),
        ],
      );
    }
    return ListView.separated(
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (profile['avatar_url'] ?? '').toString().isNotEmpty
                ? NetworkImage(profile['avatar_url'].toString())
                : null,
            child: (profile['avatar_url'] ?? '').toString().isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(_displayName(profile)),
          subtitle: Align(
            alignment: Alignment.centerLeft,
            child: UsernameBadge(username: profile['username'], compact: true),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ViewProfileScreen(userId: profile['id'].toString()),
            ),
          ),
        );
      },
    );
  }
}

String _displayName(Map<String, dynamic> profile) {
  final name = (profile['name'] ?? '').toString();
  final surname = (profile['surname'] ?? '').toString();
  final full = [
    name,
    surname,
  ].where((part) => part.trim().isNotEmpty).join(' ');
  return full.isEmpty ? 'Пользователь' : full;
}
