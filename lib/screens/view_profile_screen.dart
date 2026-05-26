import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import '../services/profile_sync_service.dart';
import 'edit_profile_screen.dart';
import 'interests_edit_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _photos = [];
  int _followersCount = 0;
  int _followingCount = 0;
  int _likesCount = 0;
  bool _loading = true;

  SupabaseClient get _client => Supabase.instance.client;
  ProfileSyncService get _sync => ProfileSyncService.instance;

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
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final localProfile = await _sync.getLocalProfile(user.id);
    final localPhotos = await _sync.getLocalPhotos(user.id);
    if (localProfile != null && mounted) {
      setState(() {
        _data = localProfile;
        _photos = localPhotos;
        _loading = false;
      });
    }

    await _sync.syncPending(user.id);
    if (await _sync.hasPendingSync(user.id)) {
      final pendingProfile = await _sync.getLocalProfile(user.id);
      final pendingPhotos = await _sync.getLocalPhotos(user.id);
      if (!mounted) return;
      setState(() {
        _data = pendingProfile ?? _data;
        _photos = pendingPhotos;
        _loading = false;
      });
      return;
    }

    try {
      var profile = await _client
          .from(tableName)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      profile ??= await _client
          .from(tableName)
          .insert({
            'id': user.id,
            'email': user.email,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final photos = await _loadPhotos(user.id);
      await _sync.cacheRemoteProfile(
        userId: user.id,
        profile: profile,
        photos: photos,
      );
      final cachedPhotos = await _sync.getLocalPhotos(user.id);
      final followers = await _loadCount(
        table: 'profile_follows',
        column: 'following_id',
        userId: user.id,
      );
      final following = await _loadCount(
        table: 'profile_follows',
        column: 'follower_id',
        userId: user.id,
      );
      final likes = await _loadCount(
        table: 'profile_likes',
        column: 'target_user_id',
        userId: user.id,
      );

      if (!mounted) return;
      setState(() {
        _data = profile;
        _photos = cachedPhotos;
        _followersCount = followers;
        _followingCount = following;
        _likesCount = likes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadPhotos(String userId) async {
    try {
      final photos = await _client
          .from('profile_photos')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(photos);
    } catch (_) {
      return [];
    }
  }

  Future<int> _loadCount({
    required String table,
    required String column,
    required String userId,
  }) async {
    try {
      return await _client.from(table).count().eq(column, userId);
    } catch (_) {
      return 0;
    }
  }

  int? _ageFromBirthDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final birthDate = DateTime.tryParse(value);
    if (birthDate == null) return null;

    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final birthdayThisYear = DateTime(now.year, birthDate.month, birthDate.day);
    if (now.isBefore(birthdayThisYear)) age--;
    return age >= 0 ? age : null;
  }

  String _capitalizeFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _profileName(Map<String, dynamic> data) {
    final name = _capitalizeFirst((data['name'] ?? '').toString());
    final surname = _capitalizeFirst((data['surname'] ?? '').toString());
    final fullName = [name, surname].where((part) => part.isNotEmpty).join(' ');
    return fullName.isNotEmpty ? fullName : 'Имя';
  }

  String _residence(Map<String, dynamic> data) {
    final city = (data['residence_city'] ?? data['city'] ?? '').toString();
    final region = (data['residence_region'] ?? '').toString();
    final country = (data['residence_country'] ?? data['country'] ?? 'Россия')
        .toString();
    final parts = [
      region,
      city,
      country,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).toList();

    return parts.isNotEmpty ? parts.join(', ') : 'Место жительства не указано';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return const Scaffold(body: Center(child: Text('Профиль не найден')));
    }

    final profile = _data!;
    final avatar = (profile['avatar_url'] ?? '').toString();
    final localAvatar = (profile['local_avatar_path'] ?? '').toString();
    final avatarPhoto = _avatarPhoto(profile);
    final galleryPhotos = [?avatarPhoto, ..._photos];
    final name = _profileName(profile);
    final age = _ageFromBirthDate(profile['birth_date']?.toString());
    final bio = _capitalizeFirst((profile['bio'] ?? '').toString());

    return Scaffold(
      backgroundColor: const Color(0xFFFFE8C8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 10),
              GestureDetector(
                onTap: avatarPhoto == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _PhotoViewerScreen(
                              photo: avatarPhoto,
                              canDelete: false,
                            ),
                          ),
                        );
                      },
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : (localAvatar.isNotEmpty
                            ? FileImage(File(localAvatar))
                            : null),
                  child: avatar.isEmpty && localAvatar.isEmpty
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$name${age != null ? ', $age' : ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _residence(profile),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(label: 'Подписчиков', value: _followersCount),
                  _StatItem(label: 'Подписок', value: _followingCount),
                  _StatItem(label: 'Лайков', value: _likesCount),
                ],
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
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          bio.isNotEmpty ? bio : 'Пока ничего не написано...',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    _PhotoGrid(
                      photos: galleryPhotos,
                      onPhotoChanged: _loadProfile,
                    ),
                  ],
                ),
              ),
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
                                builder: (_) => const InterestsEditScreen(),
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
                    _InterestsWrap(interests: profile['interests']),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _avatarPhoto(Map<String, dynamic> profile) {
    final avatarUrl = (profile['avatar_url'] ?? '').toString();
    final localAvatar = (profile['local_avatar_path'] ?? '').toString();
    if (avatarUrl.isEmpty && localAvatar.isEmpty) return null;
    return {
      'id': -1,
      'image_url': avatarUrl,
      'local_path': localAvatar,
      'storage_path': '',
      'is_avatar': true,
    };
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.pink,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _InterestsWrap extends StatelessWidget {
  const _InterestsWrap({required this.interests});

  final Object? interests;

  @override
  Widget build(BuildContext context) {
    final values = interests is List
        ? (interests as List).map((interest) => interest.toString()).toList()
        : <String>[];

    if (values.isEmpty) {
      return const Text(
        'Интересы не выбраны',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (interest) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                interest,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onPhotoChanged});

  final List<Map<String, dynamic>> photos;
  final VoidCallback onPhotoChanged;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(child: Text('Фотографии пока не добавлены'));
    }

    final pages = <List<Map<String, dynamic>>>[];
    for (var index = 0; index < photos.length; index += 6) {
      final end = (index + 6).clamp(0, photos.length);
      pages.add(photos.sublist(index, end));
    }

    return PageView.builder(
      itemCount: pages.length,
      itemBuilder: (context, pageIndex) {
        final pagePhotos = pages[pageIndex];
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          itemCount: pagePhotos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final url = (pagePhotos[index]['image_url'] ?? '').toString();
            final localPath = (pagePhotos[index]['local_path'] ?? '')
                .toString();
            return GestureDetector(
              onTap: () async {
                final deleted = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PhotoViewerScreen(
                      photo: pagePhotos[index],
                      canDelete: pagePhotos[index]['is_avatar'] != true,
                    ),
                  ),
                );
                if (deleted == true) onPhotoChanged();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _BrokenPhoto(),
                      )
                    : localPath.isNotEmpty
                    ? Image.file(
                        File(localPath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _BrokenPhoto(),
                      )
                    : const _BrokenPhoto(),
              ),
            );
          },
        );
      },
    );
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({required this.photo, required this.canDelete});

  final Map<String, dynamic> photo;
  final bool canDelete;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  bool _deleting = false;

  Future<void> _deletePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Фото будет удалено из профиля.'),
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
    if (confirm != true) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _deleting = true);
    await ProfileSyncService.instance.deletePhoto(
      userId: user.id,
      photo: widget.photo,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final url = (widget.photo['image_url'] ?? '').toString();
    final localPath = (widget.photo['local_path'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (widget.canDelete)
            IconButton(
              onPressed: _deleting ? null : _deletePhoto,
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const _BrokenPhoto(),
                )
              : localPath.isNotEmpty
              ? Image.file(
                  File(localPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const _BrokenPhoto(),
                )
              : const _BrokenPhoto(),
        ),
      ),
    );
  }
}

class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey,
      child: const Icon(Icons.broken_image, color: Colors.white),
    );
  }
}
