import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import 'local_profile_store.dart';

class ProfileSyncService {
  ProfileSyncService._();

  static final ProfileSyncService instance = ProfileSyncService._();
  static const Duration _remoteTimeout = Duration(seconds: 25);

  final LocalProfileStore _store = LocalProfileStore.instance;

  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>?> getLocalProfile(String userId) {
    return _store.getProfile(userId);
  }

  Future<List<Map<String, dynamic>>> getLocalPhotos(String userId) {
    return _store.getPhotos(userId);
  }

  Future<bool> hasPendingSync(String userId) {
    return _store.hasPendingSync(userId);
  }

  Future<void> cacheRemoteProfile({
    required String userId,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> photos,
  }) async {
    await _store.saveProfile(userId, profile);
    await _store.replaceRemotePhotos(userId, photos);
  }

  Future<List<Object>> saveProfileAndSync({
    required String userId,
    required Map<String, dynamic> profileData,
    File? avatarFile,
    List<File> photoFiles = const [],
    bool waitForSync = false,
  }) async {
    final localProfile = Map<String, dynamic>.from(profileData);
    if (avatarFile != null) {
      localProfile['local_avatar_path'] = avatarFile.path;
    } else {
      final current = await _store.getProfile(userId);
      final currentLocalPath = current?['local_avatar_path']?.toString();
      final currentAvatarUrl = current?['avatar_url']?.toString();
      if (currentLocalPath != null &&
          currentLocalPath.isNotEmpty &&
          (currentAvatarUrl == null || currentAvatarUrl.isEmpty)) {
        localProfile['local_avatar_path'] = currentLocalPath;
      }
    }
    localProfile['is_avatar_pending'] = avatarFile != null;
    await _store.saveProfile(userId, localProfile);

    if (waitForSync) {
      await _syncProfile(userId, {
        'profileData': profileData,
        'avatarPath': avatarFile?.path,
      }).timeout(_remoteTimeout);
      final photoErrors = <Object>[];
      for (final photo in photoFiles) {
        final localPhotoId = await _store.addLocalPhoto(userId, photo.path);
        try {
          await _syncPhoto(userId, {
            'localPhotoId': localPhotoId,
            'localPath': photo.path,
          }).timeout(_remoteTimeout);
        } catch (error) {
          photoErrors.add(error);
          await _store.deletePhoto(localPhotoId);
        }
      }
      return photoErrors;
    }

    await _store.enqueue(
      userId: userId,
      type: 'profile_upsert',
      payload: {'profileData': profileData, 'avatarPath': avatarFile?.path},
    );

    for (final photo in photoFiles) {
      final localPhotoId = await _store.addLocalPhoto(userId, photo.path);
      await _store.enqueue(
        userId: userId,
        type: 'photo_upload',
        payload: {'localPhotoId': localPhotoId, 'localPath': photo.path},
      );
    }

    unawaited(syncPending(userId));
    return const [];
  }

  Future<void> syncPending(String userId, {bool throwOnError = false}) async {
    final items = await _store.queue(userId);
    Object? firstError;
    for (final item in items) {
      final id = item['id'] as int;
      final type = item['type'] as String;
      final payload = Map<String, dynamic>.from(
        jsonDecode(item['payload'] as String),
      );

      try {
        if (type == 'profile_upsert') {
          await _syncProfile(userId, payload).timeout(_remoteTimeout);
        } else if (type == 'photo_upload') {
          await _syncPhoto(userId, payload).timeout(_remoteTimeout);
        } else if (type == 'photo_delete') {
          await _syncPhotoDelete(payload).timeout(_remoteTimeout);
        }
        await _store.removeQueueItem(id);
      } catch (error) {
        await _store.incrementQueueAttempts(id);
        firstError ??= error;
        if (throwOnError) break;
      }
    }
    if (throwOnError && firstError != null) throw firstError;
  }

  Future<void> clearUserData(String userId) {
    return _store.clearUserData(userId);
  }

  Future<void> deletePhoto({
    required String userId,
    required Map<String, dynamic> photo,
  }) async {
    final localId = photo['id'] as int?;
    final storagePath = photo['storage_path']?.toString();
    if (localId != null) {
      await _store.deletePhoto(localId);
      await _store.removePhotoUploadQueueItem(localId);
    }
    if (storagePath != null && storagePath.isNotEmpty) {
      await _store.enqueue(
        userId: userId,
        type: 'photo_delete',
        payload: {'storagePath': storagePath},
      );
      await syncPending(userId);
    }
  }

  Future<void> _syncProfile(String userId, Map<String, dynamic> payload) async {
    final profileData = Map<String, dynamic>.from(
      payload['profileData'] as Map,
    );
    profileData.remove('local_avatar_path');
    final avatarPath = payload['avatarPath']?.toString();
    var avatarUploaded = false;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final avatarFile = File(avatarPath);
      if (await avatarFile.exists()) {
        try {
          final storagePath = await _uploadImage(
            file: avatarFile,
            userId: userId,
            folder: 'avatars',
          ).timeout(_remoteTimeout);
          profileData['avatar_url'] = _client.storage
              .from('avatars')
              .getPublicUrl(storagePath);
          avatarUploaded = true;
        } catch (_) {}
      }
    }

    await _client.from(tableName).upsert(profileData).timeout(_remoteTimeout);
    final localProfile = Map<String, dynamic>.from(profileData);
    if (avatarPath != null && avatarPath.isNotEmpty) {
      localProfile['local_avatar_path'] = avatarPath;
      localProfile['is_avatar_pending'] = !avatarUploaded;
    }
    await _store.saveProfile(userId, localProfile);
  }

  Future<void> _syncPhoto(String userId, Map<String, dynamic> payload) async {
    final localPath = payload['localPath']?.toString();
    final localPhotoId = payload['localPhotoId'] as int?;
    if (localPath == null || localPhotoId == null) return;

    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('Photo file is not available: $localPath');
    }

    final storagePath = await _uploadImage(
      file: file,
      userId: userId,
      folder: 'profile_photos',
    );
    final imageUrl = _client.storage.from('avatars').getPublicUrl(storagePath);
    await _client.from('profile_photos').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'storage_path': storagePath,
    });
    await _store.markPhotoSynced(
      localId: localPhotoId,
      imageUrl: imageUrl,
      storagePath: storagePath,
    );
  }

  Future<void> _syncPhotoDelete(Map<String, dynamic> payload) async {
    final storagePath = payload['storagePath']?.toString();
    if (storagePath == null || storagePath.isEmpty) return;

    await _client
        .from('profile_photos')
        .delete()
        .eq('storage_path', storagePath);
    await _client.storage.from('avatars').remove([storagePath]);
  }

  Future<String> _uploadImage({
    required File file,
    required String userId,
    required String folder,
  }) async {
    final extension = _extensionFor(file);
    final storagePath =
        '$folder/$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';

    await _client.storage
        .from('avatars')
        .upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: _contentType(file),
            upsert: true,
          ),
        );
    return storagePath;
  }

  String _contentType(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _extensionFor(File file) {
    switch (_contentType(file)) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }
}
