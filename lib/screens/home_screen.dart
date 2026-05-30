import 'package:flutter/material.dart';

import '../services/social_service.dart';
import 'view_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _social = SocialService.instance;
  List<Map<String, dynamic>> _feed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _search.addListener(_loadFeed);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    try {
      final feed = await _social.loadFeed(query: _search.text);
      if (mounted) {
        setState(() {
          _feed = feed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    await _social.togglePhotoLike(item['id'].toString(), item['liked'] == true);
    await _loadFeed();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Лента'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
                : RefreshIndicator(
                    onRefresh: _loadFeed,
                    child: _feed.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 160),
                              Center(child: Text('В ленте пока нет фото')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: _feed.length,
                            itemBuilder: (context, index) => _FeedCard(
                              item: _feed[index],
                              onLike: () => _toggleLike(_feed[index]),
                              onOpenProfile: () {
                                final profile = Map<String, dynamic>.from(
                                  _feed[index]['profile'] as Map,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ViewProfileScreen(
                                      userId: profile['id'].toString(),
                                    ),
                                  ),
                                ).then((_) => _loadFeed());
                              },
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.item,
    required this.onLike,
    required this.onOpenProfile,
  });

  final Map<String, dynamic> item;
  final VoidCallback onLike;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(item['profile'] as Map);
    final liked = item['liked'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        (profile['avatar_url'] ?? '').toString().isNotEmpty
                        ? NetworkImage(profile['avatar_url'].toString())
                        : null,
                    child: (profile['avatar_url'] ?? '').toString().isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: onOpenProfile,
                      child: Text(
                        SocialService.instance.usernameLabel(profile['username']),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: ProfilePhotoImage(photo: item, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.pinkAccent : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item['likes_count'] ?? 0}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
