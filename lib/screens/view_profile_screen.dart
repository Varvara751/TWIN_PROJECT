import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_sync_service.dart';
import '../services/social_service.dart';
import '../widgets/username_badge.dart';
import 'edit_profile_screen.dart';
import 'interests_edit_screen.dart';
import 'messenger_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _photos = [];
  int _followersCount = 0;
  int _followingCount = 0;
  int _likesCount = 0;
  bool _following = false;
  bool _loading = true;
  bool _actionBusy = false;

  SupabaseClient get _client => Supabase.instance.client;
  ProfileSyncService get _sync => ProfileSyncService.instance;
  SocialService get _social => SocialService.instance;

  String? get _currentUserId => _client.auth.currentUser?.id;
  String? get _targetUserId => widget.userId ?? _currentUserId;
  bool get _isOwnProfile => _targetUserId == _currentUserId;

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
    final userId = _targetUserId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (_isOwnProfile) {
      final localProfile = await _sync.getLocalProfile(userId);
      final localPhotos = await _sync.getLocalPhotos(userId);
      if (mounted) {
        setState(() {
          _profile = localProfile ?? _fallbackOwnProfile(userId);
          _photos = localPhotos;
          _loading = false;
        });
      }
      await _sync.syncPending(userId);
    }

    try {
      var profile = await _social.loadProfile(userId);
      profile ??= _isOwnProfile ? await _createOwnProfile(userId) : null;
      if (profile == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final photos = await _loadPhotos(userId);
      if (_isOwnProfile) {
        await _sync.cacheRemoteProfile(
          userId: userId,
          profile: profile,
          photos: photos,
        );
      }
      final visiblePhotos = _isOwnProfile
          ? [...await _pendingLocalPhotos(userId), ...photos]
          : photos;
      final followers = await _social.followersCount(userId);
      final following = await _social.followingCount(userId);
      final likes = await _social.totalPhotoLikesCount(userId);
      final follows = !_isOwnProfile
          ? await _social.isFollowing(userId)
          : false;

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _photos = visiblePhotos;
        _followersCount = followers;
        _followingCount = following;
        _likesCount = likes;
        _following = follows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_isOwnProfile) {
          _profile ??= _fallbackOwnProfile(userId);
        }
        _loading = false;
      });
      _showMessage('Не удалось загрузить профиль: $e');
    }
  }

  Map<String, dynamic> _fallbackOwnProfile(String userId) {
    final email = _client.auth.currentUser?.email ?? '';
    return {
      'id': userId,
      'email': email,
      'username': 'user_${userId.substring(0, 8)}',
      'name': email.contains('@') ? email.split('@').first : '',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _createOwnProfile(String userId) async {
    final profile = _fallbackOwnProfile(userId);
    await _sync.saveProfileAndSync(userId: userId, profileData: profile);
    return profile;
  }

  Future<List<Map<String, dynamic>>> _loadPhotos(String userId) async {
    try {
      return await _social.loadProfilePhotos(userId);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _pendingLocalPhotos(String userId) async {
    final photos = await _sync.getLocalPhotos(userId);
    return photos.where((photo) => photo['synced'] != 1).toList();
  }

  int? _ageFromBirthDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final birthDate = DateTime.tryParse(value);
    if (birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.isBefore(DateTime(now.year, birthDate.month, birthDate.day))) age--;
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
    return parts.isEmpty ? 'Место жительства не указано' : parts.join(', ');
  }

  Future<void> _toggleFollow() async {
    final userId = _targetUserId;
    if (userId == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await _social.toggleFollow(userId, _following);
      await _loadProfile();
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _togglePhotoLike(Map<String, dynamic> photo) async {
    final photoId = photo['id']?.toString() ?? '';
    if (photoId.isEmpty || photoId.startsWith('-') || photo['synced'] == 0) {
      return;
    }
    await _social.togglePhotoLike(photoId, photo['liked'] == true);
    await _loadProfile();
  }

  Future<void> _openChat() async {
    final userId = _targetUserId;
    if (userId == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final chatId = await _social.openChatWith(userId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatThreadScreen(chatId: chatId, otherProfile: _profile ?? {}),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('Профиль не найден')));
    }

    final avatarPhoto = _avatarPhoto(profile);
    final galleryPhotos = _isOwnProfile ? [?avatarPhoto, ..._photos] : _photos;
    final name = _profileName(profile);
    final age = _ageFromBirthDate(profile['birth_date']?.toString());
    final bio = _capitalizeFirst((profile['bio'] ?? '').toString());

    return Scaffold(
      backgroundColor: const Color(0xFFFFE8C8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: !_isOwnProfile,
        title: Text(_isOwnProfile ? 'Профиль' : name),
        centerTitle: true,
        actions: [
          if (_isOwnProfile)
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
              _Avatar(profile: profile, photo: avatarPhoto),
              const SizedBox(height: 10),
              Text(
                '$name${age != null ? ', $age' : ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              UsernameBadge(username: profile['username']),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  _residence(profile),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              if (!_isOwnProfile)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _actionBusy ? null : _toggleFollow,
                          icon: Icon(
                            _following ? Icons.check : Icons.person_add_alt_1,
                          ),
                          label: Text(
                            _following ? 'Вы подписаны' : 'Подписаться',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _actionBusy ? null : _openChat,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Сообщение'),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(label: 'Подписчики', value: _followersCount),
                  _StatItem(label: 'Подписки', value: _followingCount),
                  _StatItem(label: 'Лайки', value: _likesCount),
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
                height: 300,
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
                      canDelete: _isOwnProfile,
                      onPhotoChanged: _loadProfile,
                      onLike: _togglePhotoLike,
                    ),
                  ],
                ),
              ),
              if (_isOwnProfile)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _InterestsSection(
                    interests: profile['interests'],
                    onChanged: _loadProfile,
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
      'id': '-avatar',
      'image_url': avatarUrl,
      'local_path': localAvatar,
      'storage_path': '',
      'is_avatar': true,
    };
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.photo});

  final Map<String, dynamic> profile;
  final Map<String, dynamic>? photo;

  @override
  Widget build(BuildContext context) {
    final avatar = (profile['avatar_url'] ?? '').toString();
    final localAvatar = (profile['local_avatar_path'] ?? '').toString();
    ImageProvider? image;
    if (localAvatar.isNotEmpty && File(localAvatar).existsSync()) {
      image = FileImage(File(localAvatar));
    } else if (avatar.isNotEmpty) {
      image = NetworkImage(avatar);
    }
    return GestureDetector(
      onTap: photo == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    _PhotoViewerScreen(photo: photo!, canDelete: false),
              ),
            ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        backgroundImage: image,
        child: image == null
            ? const Icon(Icons.person, size: 50, color: Colors.grey)
            : null,
      ),
    );
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

class _InterestsSection extends StatelessWidget {
  const _InterestsSection({required this.interests, required this.onChanged});

  final Object? interests;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final values = interests is List
        ? (interests as List).map((interest) => interest.toString()).toList()
        : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Мои интересы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InterestsEditScreen()),
              ).then((_) => onChanged()),
              icon: const Icon(Icons.edit, size: 18),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.isEmpty
              ? [
                  const Text(
                    'Интересы не выбраны',
                    style: TextStyle(color: Colors.grey),
                  ),
                ]
              : values
                    .map(
                      (interest) => Chip(
                        label: Text(interest),
                        backgroundColor: Colors.white,
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.canDelete,
    required this.onPhotoChanged,
    required this.onLike,
  });

  final List<Map<String, dynamic>> photos;
  final bool canDelete;
  final VoidCallback onPhotoChanged;
  final Future<void> Function(Map<String, dynamic> photo) onLike;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(child: Text('Фотографии пока не добавлены'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final canLike =
            photo['is_avatar'] != true &&
            photo['synced'] != 0 &&
            !(photo['id']?.toString() ?? '').startsWith('-');
        final liked = photo['liked'] == true;
        return GestureDetector(
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => _PhotoViewerScreen(
                  photo: photo,
                  canDelete: canDelete && photo['is_avatar'] != true,
                  canLike: canLike,
                ),
              ),
            );
            if (changed == true) onPhotoChanged();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfilePhotoImage(photo: photo, fit: BoxFit.cover),
                if (canLike)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: InkWell(
                      onTap: () => onLike(photo),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: liked ? Colors.pinkAccent : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${photo['likes_count'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfilePhotoImage extends StatelessWidget {
  const ProfilePhotoImage({super.key, required this.photo, this.fit});

  final Map<String, dynamic> photo;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    final localPath = (photo['local_path'] ?? '').toString();
    final url = (photo['image_url'] ?? '').toString();
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: fit,
        errorBuilder: (_, _, _) => const _BrokenPhoto(),
      );
    }
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(
            color: Color(0xFFECECEC),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (_, _, _) => const _BrokenPhoto(),
      );
    }
    return const _BrokenPhoto();
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({
    required this.photo,
    required this.canDelete,
    this.canLike = false,
  });

  final Map<String, dynamic> photo;
  final bool canDelete;
  final bool canLike;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  bool _deleting = false;
  late bool _liked;
  late int _likesCount;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.photo['liked'] == true;
    _likesCount = int.tryParse('${widget.photo['likes_count'] ?? 0}') ?? 0;
  }

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
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _toggleLike() async {
    final photoId = widget.photo['id']?.toString() ?? '';
    if (!widget.canLike || photoId.isEmpty || photoId.startsWith('-')) return;
    await SocialService.instance.togglePhotoLike(photoId, _liked);
    if (!mounted) return;
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
      if (_likesCount < 0) _likesCount = 0;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            if (widget.canLike)
              TextButton.icon(
                onPressed: _toggleLike,
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? Colors.pinkAccent : Colors.white,
                ),
                label: Text(
                  '$_likesCount',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
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
            child: ProfilePhotoImage(photo: widget.photo, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE0E0E0),
      child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }
}
