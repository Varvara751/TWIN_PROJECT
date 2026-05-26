import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import '../core/russian_cities.dart';
import '../core/russian_regions.dart';
import '../services/profile_sync_service.dart';

const int _maxPhotosPerSave = 5;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _residenceCity = TextEditingController();
  final _bio = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _avatarFile;
  String? _currentAvatarUrl;
  String? _currentLocalAvatarPath;
  List<File> _newPhotoFiles = [];
  int? _birthYear;
  int? _birthMonth;
  int? _birthDay;
  String? _residenceRegion;
  bool _saving = false;
  bool _loading = true;

  SupabaseClient get _client => Supabase.instance.client;
  ProfileSyncService get _sync => ProfileSyncService.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _residenceCity.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      var res = await _sync.getLocalProfile(user.id);
      if (res == null) {
        res = await _client.from(tableName).select().eq('id', user.id).single();
        await _sync.cacheRemoteProfile(
          userId: user.id,
          profile: res,
          photos: const [],
        );
      }
      final profile = res;
      final birthDate = DateTime.tryParse(
        (profile['birth_date'] ?? '').toString(),
      );
      final savedRegion = (profile['residence_region'] ?? '').toString();

      if (!mounted) return;
      setState(() {
        _name.text = profile['name'] ?? '';
        _surname.text = profile['surname'] ?? '';
        _residenceCity.text =
            profile['residence_city'] ?? profile['city'] ?? '';
        _bio.text = profile['bio'] ?? '';
        _currentAvatarUrl = profile['avatar_url'];
        _currentLocalAvatarPath = profile['local_avatar_path'];
        _birthYear = birthDate?.year;
        _birthMonth = birthDate?.month;
        _birthDay = birthDate?.day;
        _residenceRegion = russianRegions.contains(savedRegion)
            ? savedRegion
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Ошибка загрузки профиля: $e');
    }
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (image == null) return;

    final prepared = await _prepareImageFile(image);
    if (!mounted) return;
    setState(() => _avatarFile = prepared);
  }

  Future<void> _pickProfilePhotos() async {
    final remaining = _maxPhotosPerSave - _newPhotoFiles.length;
    if (remaining <= 0) {
      _showMessage('За один раз можно прикрепить не больше 5 фото');
      return;
    }

    final images = await _picker.pickMultiImage(
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
      limit: remaining,
    );
    if (images.isEmpty) return;

    final selectedImages = images.take(remaining).toList();
    if (images.length > remaining) {
      _showMessage('Добавлены первые $remaining фото. Лимит - 5 фото за раз');
    }

    final files = <File>[];
    for (final image in selectedImages) {
      files.add(await _prepareImageFile(image));
    }

    if (!mounted) return;
    setState(() => _newPhotoFiles = [..._newPhotoFiles, ...files]);
  }

  Future<File> _prepareImageFile(XFile image) async {
    final source = File(image.path);
    final targetPath = _compressedPath(image.path);

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        minWidth: 1200,
        minHeight: 1200,
        quality: 82,
        format: CompressFormat.jpeg,
      );
      if (result != null) return File(result.path);
    } catch (_) {
      // The original file is still valid; upload should not fail just because
      // local compression is unavailable on a platform.
    }

    return source;
  }

  String _compressedPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '${path}_compressed.jpg';
    return '${path.substring(0, dotIndex)}_compressed.jpg';
  }

  DateTime? _selectedBirthDate() {
    if (_birthYear == null || _birthMonth == null || _birthDay == null) {
      return null;
    }
    final date = DateTime(_birthYear!, _birthMonth!, _birthDay!);
    if (date.year != _birthYear ||
        date.month != _birthMonth ||
        date.day != _birthDay) {
      return null;
    }
    if (date.isAfter(DateTime.now())) return null;
    return date;
  }

  int? _selectedAge() {
    final birthDate = _selectedBirthDate();
    if (birthDate == null) return null;

    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final birthdayThisYear = DateTime(now.year, birthDate.month, birthDate.day);
    if (now.isBefore(birthdayThisYear)) age--;
    return age >= 0 ? age : null;
  }

  ImageProvider? _avatarProvider() {
    if (_avatarFile != null) return FileImage(_avatarFile!);
    final avatarUrl = _currentAvatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      final localPath = _currentLocalAvatarPath;
      if (localPath == null || localPath.isEmpty) return null;
      return FileImage(File(localPath));
    }
    return NetworkImage(avatarUrl);
  }

  List<int> _availableDays() {
    if (_birthYear == null || _birthMonth == null) {
      return List.generate(31, (index) => index + 1);
    }
    final nextMonth = _birthMonth == 12
        ? DateTime(_birthYear! + 1, 1)
        : DateTime(_birthYear!, _birthMonth! + 1);
    final days = nextMonth.subtract(const Duration(days: 1)).day;
    return List.generate(days, (index) => index + 1);
  }

  String _capitalizeFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalizeFirst)
        .join(' ');
  }

  Future<void> _save() async {
    if (_saving) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    final birthDate = _selectedBirthDate();
    if (_birthYear != null || _birthMonth != null || _birthDay != null) {
      if (birthDate == null) {
        _showMessage('Укажите корректную дату рождения');
        return;
      }
    }
    if (_residenceCity.text.trim().isNotEmpty && _residenceRegion == null) {
      _showMessage('Выберите субъект РФ');
      return;
    }

    setState(() => _saving = true);
    try {
      final profileData = <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'name': _normalizeName(_name.text),
        'surname': _normalizeName(_surname.text),
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'residence_city': _capitalizeFirst(_residenceCity.text),
        'residence_region': _residenceRegion,
        'residence_country': 'Россия',
        'bio': _capitalizeFirst(_bio.text),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _sync.saveProfileAndSync(
        userId: user.id,
        profileData: profileData,
        avatarFile: _avatarFile,
        photoFiles: _newPhotoFiles,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (e is PostgrestException && e.code == 'PGRST204') {
        _showMessage(
          'База Supabase не обновлена. Примените миграцию профиля и попробуйте снова.',
        );
      } else {
        _showMessage('Ошибка: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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

    final age = _selectedAge();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _avatarProvider(),
                  child:
                      _avatarFile == null &&
                          (_currentAvatarUrl == null ||
                              _currentAvatarUrl!.isEmpty) &&
                          (_currentLocalAvatarPath == null ||
                              _currentLocalAvatarPath!.isEmpty)
                      ? const Icon(Icons.camera_alt, size: 30)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildField('Имя', _name),
            _buildField('Фамилия', _surname),
            _buildBirthDateFields(age),
            _buildRegionDropdown(),
            _buildCityAutocomplete(),
            _buildField('О себе', _bio, maxLines: 3),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickProfilePhotos,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Добавить фотографии'),
            ),
            if (_newPhotoFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SelectedPhotos(
                files: _newPhotoFiles,
                onRemove: (index) {
                  setState(() {
                    _newPhotoFiles = [..._newPhotoFiles]..removeAt(index);
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBirthDateFields(int? age) {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (index) => currentYear - index);
    final months = List.generate(12, (index) => index + 1);
    final days = _availableDays();
    final selectedDay = days.contains(_birthDay) ? _birthDay : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown<int>(
                  label: 'Год',
                  value: _birthYear,
                  items: years,
                  itemLabel: (value) => value.toString(),
                  onChanged: (value) => setState(() {
                    _birthYear = value;
                    if (!_availableDays().contains(_birthDay)) {
                      _birthDay = null;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown<int>(
                  label: 'Месяц',
                  value: _birthMonth,
                  items: months,
                  itemLabel: (value) => value.toString().padLeft(2, '0'),
                  onChanged: (value) => setState(() {
                    _birthMonth = value;
                    if (!_availableDays().contains(_birthDay)) {
                      _birthDay = null;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown<int>(
                  label: 'Число',
                  value: selectedDay,
                  items: days,
                  itemLabel: (value) => value.toString().padLeft(2, '0'),
                  onChanged: (value) => setState(() => _birthDay = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            age == null ? 'Возраст: не указан' : 'Возраст: $age',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        initialValue: _residenceRegion,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Субъект РФ',
          border: OutlineInputBorder(),
        ),
        items: russianRegions
            .map(
              (region) => DropdownMenuItem(
                value: region,
                child: Text(region, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() {
          _residenceRegion = value;
          _residenceCity.clear();
        }),
      ),
    );
  }

  Widget _buildCityAutocomplete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Autocomplete<String>(
        key: ValueKey(_residenceRegion),
        initialValue: TextEditingValue(text: _residenceCity.text),
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) return const Iterable<String>.empty();

          final cities = russianCitiesForRegion(_residenceRegion);
          return cities
              .where((city) {
                final lowerCity = city.toLowerCase();
                return lowerCity.startsWith(query) || lowerCity.contains(query);
              })
              .take(8);
        },
        onSelected: (city) => _residenceCity.text = city,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            onChanged: (value) => _residenceCity.text = value,
            decoration: const InputDecoration(
              labelText: 'Город',
              border: OutlineInputBorder(),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T value) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        textInputAction: maxLines == 1 ? TextInputAction.next : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _SelectedPhotos extends StatelessWidget {
  const _SelectedPhotos({required this.files, required this.onRemove});

  final List<File> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(files[index], fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () => onRemove(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
