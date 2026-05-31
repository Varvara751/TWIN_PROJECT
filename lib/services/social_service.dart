import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';

class SocialService {
  SocialService._();

  static final SocialService instance = SocialService._();

  SupabaseClient get _client => Supabase.instance.client;

  String get currentUserId => _client.auth.currentUser!.id;

  String normalizeUsername(String value) {
    return value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
  }

  bool isValidUsername(String value) {
    final normalized = normalizeUsername(value);
    return RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalized);
  }

  String usernameLabel(Object? value) {
    final username = (value ?? '').toString().trim();
    return username.isEmpty ? '@username' : '@$username';
  }

  Future<bool> isUsernameAvailable(String username, String userId) async {
    final normalized = normalizeUsername(username);
    final row = await _client
        .from(tableName)
        .select('id')
        .eq('username', normalized)
        .neq('id', userId)
        .maybeSingle();
    return row == null;
  }

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final clean = query.trim().replaceFirst(RegExp(r'^@+'), '');
    if (clean.isEmpty) return [];

    final response = await _client
        .from(tableName)
        .select('id, name, surname, username, avatar_url, residence_city, city')
        .or(
          'username.ilike.%$clean%,name.ilike.%$clean%,surname.ilike.%$clean%',
        )
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> loadProfile(String userId) async {
    return await _client
        .from(tableName)
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> loadFeed({String query = ''}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final clean = query.trim().replaceFirst(RegExp(r'^@+'), '');
    final photoRows = clean.isEmpty
        ? List<Map<String, dynamic>>.from(
            await _client
                .from('profile_photos')
                .select('id, user_id, image_url, storage_path, created_at')
                .order('created_at', ascending: false)
                .limit(80),
          )
        : await _feedSearchPhotos(clean);
    if (photoRows.isEmpty) return [];

    final userIds = photoRows
        .map((photo) => photo['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final profiles = await _client
        .from(tableName)
        .select('id, name, surname, username, avatar_url, residence_city, city')
        .inFilter('id', userIds);
    final profileById = {
      for (final profile in List<Map<String, dynamic>>.from(profiles))
        profile['id'].toString(): profile,
    };

    final photoStateById = await _photoStateById(photoRows);

    final result = <Map<String, dynamic>>[];
    for (final photo in photoRows) {
      final profile = profileById[photo['user_id'].toString()];
      if (profile == null) continue;
      final state = photoStateById[photo['id'].toString()] ?? {};
      result.add({...photo, 'profile': profile, ...state});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> loadProfilePhotos(String userId) async {
    final rows = await _client
        .from('profile_photos')
        .select('id, user_id, image_url, storage_path, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final photos = List<Map<String, dynamic>>.from(rows);
    if (photos.isEmpty) return [];
    final stateById = await _photoStateById(photos);
    return photos
        .map((photo) => {...photo, ...?stateById[photo['id'].toString()]})
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> _photoStateById(
    List<Map<String, dynamic>> photos,
  ) async {
    final user = _client.auth.currentUser;
    final photoIds = photos
        .map((photo) => photo['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty && !id.startsWith('-'))
        .toList();
    if (photoIds.isEmpty) return {};

    final likedIds = <String>{};
    if (user != null) {
      final likedRows = await _client
          .from('profile_photo_likes')
          .select('photo_id')
          .eq('source_user_id', user.id)
          .inFilter('photo_id', photoIds);
      likedIds.addAll(
        List<Map<String, dynamic>>.from(
          likedRows,
        ).map((row) => row['photo_id'].toString()),
      );
    }

    final likeRows = await _client
        .from('profile_photo_likes')
        .select('photo_id')
        .inFilter('photo_id', photoIds);
    final likesCountByPhotoId = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(likeRows)) {
      final photoId = row['photo_id']?.toString();
      if (photoId == null) continue;
      likesCountByPhotoId[photoId] = (likesCountByPhotoId[photoId] ?? 0) + 1;
    }

    return {
      for (final id in photoIds)
        id: {
          'liked': likedIds.contains(id),
          'likes_count': likesCountByPhotoId[id] ?? 0,
        },
    };
  }

  Future<List<Map<String, dynamic>>> _feedSearchPhotos(String query) async {
    final clean = query.trim().replaceFirst(RegExp(r'^@+'), '');
    if (clean.isEmpty) return [];
    final profiles = List<Map<String, dynamic>>.from(
      await _client
          .from(tableName)
          .select(
            'id, name, surname, username, avatar_url, residence_city, city',
          )
          .or(
            'username.ilike.%$clean%,name.ilike.%$clean%,surname.ilike.%$clean%',
          )
          .limit(20),
    );
    if (profiles.isEmpty) return [];
    final ids = profiles.map((profile) => profile['id'].toString()).toList();
    return List<Map<String, dynamic>>.from(
      await _client
          .from('profile_photos')
          .select('id, user_id, image_url, storage_path, created_at')
          .inFilter('user_id', ids)
          .order('created_at', ascending: false)
          .limit(80),
    );
  }

  bool _profileMatches(Map<String, dynamic> profile, String query) {
    final fields = [
      profile['username'],
      profile['name'],
      profile['surname'],
    ].map((value) => (value ?? '').toString().toLowerCase());
    return fields.any((value) => value.contains(query));
  }

  Future<int> photoLikesCount(String photoId) async {
    try {
      return await _client
          .from('profile_photo_likes')
          .count()
          .eq('photo_id', photoId);
    } catch (_) {
      return 0;
    }
  }

  Future<bool> isPhotoLiked(String photoId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('profile_photo_likes')
        .select('photo_id')
        .eq('photo_id', photoId)
        .eq('source_user_id', user.id)
        .maybeSingle();
    return row != null;
  }

  Future<void> togglePhotoLike(String photoId, bool liked) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (liked) {
      await _client
          .from('profile_photo_likes')
          .delete()
          .eq('photo_id', photoId)
          .eq('source_user_id', user.id);
    } else {
      await _client.from('profile_photo_likes').upsert({
        'photo_id': photoId,
        'source_user_id': user.id,
      });
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id == targetUserId) return false;
    final row = await _client
        .from('profile_follows')
        .select('follower_id')
        .eq('follower_id', user.id)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleFollow(String targetUserId, bool following) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id == targetUserId) return;
    if (following) {
      await _client
          .from('profile_follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', targetUserId);
    } else {
      await _client.from('profile_follows').upsert({
        'follower_id': user.id,
        'following_id': targetUserId,
      });
    }
  }

  Future<int> followersCount(String userId) =>
      _count(table: 'profile_follows', column: 'following_id', value: userId);

  Future<int> followingCount(String userId) =>
      _count(table: 'profile_follows', column: 'follower_id', value: userId);

  Future<int> totalPhotoLikesCount(String userId) async {
    try {
      final photos = await _client
          .from('profile_photos')
          .select('id')
          .eq('user_id', userId);
      final photoIds = List<Map<String, dynamic>>.from(
        photos,
      ).map((row) => row['id'].toString()).toList();
      if (photoIds.isEmpty) return 0;
      return await _client
          .from('profile_photo_likes')
          .count()
          .inFilter('photo_id', photoIds);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _count({
    required String table,
    required String column,
    required String value,
  }) async {
    try {
      return await _client.from(table).count().eq(column, value);
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> followers(String userId) async {
    return _followList(userId: userId, mode: _FollowMode.followers);
  }

  Future<List<Map<String, dynamic>>> following(String userId) async {
    return _followList(userId: userId, mode: _FollowMode.following);
  }

  Future<List<Map<String, dynamic>>> _followList({
    required String userId,
    required _FollowMode mode,
  }) async {
    final column = mode == _FollowMode.followers
        ? 'following_id'
        : 'follower_id';
    final targetColumn = mode == _FollowMode.followers
        ? 'follower_id'
        : 'following_id';
    final rows = await _client
        .from('profile_follows')
        .select(targetColumn)
        .eq(column, userId)
        .order('created_at', ascending: false);
    final ids = List<Map<String, dynamic>>.from(
      rows,
    ).map((row) => row[targetColumn].toString()).toList();
    if (ids.isEmpty) return [];
    final profiles = await _client
        .from(tableName)
        .select('id, name, surname, username, avatar_url, residence_city, city')
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(profiles);
  }

  Future<String> openChatWith(String otherUserId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final ids = [user.id, otherUserId]..sort();
    final existing = await _client
        .from('chats')
        .select('id')
        .eq('user_low', ids[0])
        .eq('user_high', ids[1])
        .maybeSingle();
    if (existing != null) {
      final chatId = existing['id'].toString();
      await _client
          .from('chat_deletions')
          .delete()
          .eq('chat_id', chatId)
          .eq('user_id', user.id);
      return chatId;
    }
    final created = await _client
        .from('chats')
        .insert({'user_low': ids[0], 'user_high': ids[1]})
        .select('id')
        .single();
    return created['id'].toString();
  }

  Future<List<Map<String, dynamic>>> loadChats({String query = ''}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('chats')
        .select()
        .or('user_low.eq.${user.id},user_high.eq.${user.id}')
        .order('updated_at', ascending: false);
    final chats = List<Map<String, dynamic>>.from(rows);
    if (chats.isEmpty) return [];

    final chatIds = chats.map((chat) => chat['id'].toString()).toList();
    final deletedRows = await _client
        .from('chat_deletions')
        .select('chat_id')
        .eq('user_id', user.id)
        .inFilter('chat_id', chatIds);
    final deletedChatIds = List<Map<String, dynamic>>.from(
      deletedRows,
    ).map((row) => row['chat_id'].toString()).toSet();

    final otherIds = chats
        .where((chat) => !deletedChatIds.contains(chat['id'].toString()))
        .map(
          (chat) => chat['user_low'] == user.id
              ? chat['user_high'].toString()
              : chat['user_low'].toString(),
        )
        .toSet()
        .toList();
    if (otherIds.isEmpty) return [];

    final profileRows = await _client
        .from(tableName)
        .select('id, name, surname, username, avatar_url, residence_city, city')
        .inFilter('id', otherIds);
    final profilesById = {
      for (final profile in List<Map<String, dynamic>>.from(profileRows))
        profile['id'].toString(): profile,
    };
    final summaries = await _chatMessageSummaries(chatIds, user.id);
    final visible = <Map<String, dynamic>>[];
    for (final chat in chats) {
      final chatId = chat['id'].toString();
      if (deletedChatIds.contains(chatId)) continue;
      final otherId = chat['user_low'] == user.id
          ? chat['user_high'].toString()
          : chat['user_low'].toString();
      final profile = profilesById[otherId];
      if (profile == null) continue;
      if (query.trim().isNotEmpty &&
          !_profileMatches(
            profile,
            query.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), ''),
          )) {
        continue;
      }
      visible.add({
        ...chat,
        'other_profile': profile,
        'latest_message': summaries[chatId]?['latest_message'],
        'other_message_count': summaries[chatId]?['other_message_count'] ?? 0,
        'my_message_count': summaries[chatId]?['my_message_count'] ?? 0,
      });
    }
    return visible;
  }

  Future<Map<String, Map<String, dynamic>>> _chatMessageSummaries(
    List<String> chatIds,
    String userId,
  ) async {
    if (chatIds.isEmpty) return {};
    final rows = await _client
        .from('messages')
        .select('id, chat_id, sender_id, body, created_at')
        .inFilter('chat_id', chatIds)
        .order('created_at', ascending: false);
    final messages = List<Map<String, dynamic>>.from(rows);
    if (messages.isEmpty) return {};
    final deletions = await _client
        .from('message_deletions')
        .select('message_id')
        .eq('user_id', userId)
        .inFilter(
          'message_id',
          messages.map((message) => message['id'].toString()).toList(),
        );
    final deletedIds = List<Map<String, dynamic>>.from(
      deletions,
    ).map((row) => row['message_id'].toString()).toSet();
    final summaries = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      if (deletedIds.contains(message['id'].toString())) continue;
      final chatId = message['chat_id'].toString();
      final summary = summaries.putIfAbsent(
        chatId,
        () => {
          'latest_message': message,
          'other_message_count': 0,
          'my_message_count': 0,
        },
      );
      if (message['sender_id'] == userId) {
        summary['my_message_count'] = (summary['my_message_count'] as int) + 1;
      } else {
        summary['other_message_count'] =
            (summary['other_message_count'] as int) + 1;
      }
    }
    return summaries;
  }

  Future<List<Map<String, dynamic>>> loadMessages(String chatId) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at');
    final messages = List<Map<String, dynamic>>.from(rows);
    final deletions = await _client
        .from('message_deletions')
        .select('message_id')
        .eq('user_id', user.id);
    final deletedIds = List<Map<String, dynamic>>.from(
      deletions,
    ).map((row) => row['message_id'].toString()).toSet();
    return messages
        .where((message) => !deletedIds.contains(message['id'].toString()))
        .toList();
  }

  Future<Map<String, dynamic>?> sendMessage(String chatId, String body) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final text = body.trim();
    if (text.isEmpty) return null;
    final inserted = await _client
        .from('messages')
        .insert({'chat_id': chatId, 'sender_id': user.id, 'body': text})
        .select()
        .single();
    try {
      await _client
          .from('chats')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', chatId);
      await _client
          .from('chat_deletions')
          .delete()
          .eq('chat_id', chatId)
          .eq('user_id', user.id);
    } catch (_) {
      // The message is already saved; chat metadata can refresh on the next load.
    }
    return Map<String, dynamic>.from(inserted);
  }

  Future<void> editMessage(String messageId, String body) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final text = body.trim();
    if (text.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    try {
      await _client
          .from('messages')
          .update({'body': text, 'edited_at': now})
          .eq('id', messageId)
          .eq('sender_id', user.id);
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST204') rethrow;
      await _client
          .from('messages')
          .update({'body': text})
          .eq('id', messageId)
          .eq('sender_id', user.id);
    }
  }

  Future<void> deleteMessageForMe(String messageId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('message_deletions').upsert({
      'message_id': messageId,
      'user_id': user.id,
    });
  }

  Future<void> clearChatForMe(String chatId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final rows = await _client
        .from('messages')
        .select('id')
        .eq('chat_id', chatId);
    final messageIds = List<Map<String, dynamic>>.from(
      rows,
    ).map((row) => row['id'].toString()).toList();
    if (messageIds.isEmpty) return;
    await _client
        .from('message_deletions')
        .upsert(
          messageIds
              .map((messageId) => {'message_id': messageId, 'user_id': user.id})
              .toList(),
        );
  }

  Future<void> deleteChatForMe(String chatId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('chat_deletions').upsert({
      'chat_id': chatId,
      'user_id': user.id,
    });
  }

  Future<bool> isBlocked(String otherUserId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('chat_blocks')
        .select('blocker_id')
        .eq('blocker_id', user.id)
        .eq('blocked_id', otherUserId)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleBlock(String otherUserId, bool blocked) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (blocked) {
      await _client
          .from('chat_blocks')
          .delete()
          .eq('blocker_id', user.id)
          .eq('blocked_id', otherUserId);
    } else {
      await _client.from('chat_blocks').upsert({
        'blocker_id': user.id,
        'blocked_id': otherUserId,
      });
    }
  }
}

enum _FollowMode { followers, following }
