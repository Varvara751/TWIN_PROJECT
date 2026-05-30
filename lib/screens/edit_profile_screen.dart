import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';
import '../core/russian_cities.dart';
import '../core/russian_regions.dart';
import '../services/profile_sync_service.dart';
import '../services/social_service.dart';

const int _maxPhotosPerSave = 5;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _username = TextEditingController();
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
  bool _saved = true;
  bool _loading = true;

  SupabaseClient get _client => Supabase.instance.client;
  ProfileSyncService get _sync => ProfileSyncService.instance;
  SocialService get _social => SocialService.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _username.dispose();
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
      var profile = await _sync.getLocalProfile(user.id);
      if (profile == null) {
        profile = await _client
            .from(tableName)
            .select()
            .eq('id', user.id)
            .single();
        await _sync.cacheRemoteProfile(
          userId: user.id,
          profile: profile,
          photos: const [],
        );
      }
      final birthDate = DateTime.tryParse(
        (profile['birth_date'] ?? '').toString(),
      );
      final savedRegion = (profile['residence_region'] ?? '').toString();

      if (!mounted) return;
      setState(() {
        _name.text = (profile?['name'] ?? '').toString();
        _surname.text = (profile?['surname'] ?? '').toString();
        _username.text = _social.usernameLabel(profile?['username']);
        _residenceCity.text =
            (profile?['residence_city'] ?? profile?['city'] ?? '').toString();
        _bio.text = (profile?['bio'] ?? '').toString();
        _currentAvatarUrl = profile?['avatar_url']?.toString();
        _currentLocalAvatarPath = profile?['local_avatar_path']?.toString();
        _birthYear = birthDate?.year;
        _birthMonth = birthDate?.month;
        _birthDay = birthDate?.day;
        _residenceRegion = russianRegions.contains(savedRegion)
            ? savedRegion
            : null;
        _loading = false;
        _saved = true;
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
    if (mounted) {
      setState(() {
        _avatarFile = prepared;
        _saved = false;
      });
    }
  }

  Future<void> _pickProfilePhotos() async {
    final remaining = _maxPhotosPerSave - _newPhotoFiles.length;
    if (remaining <= 0) {
      _showMessage('За один раз можно добавить не больше 5 фото');
      return;
    }

    final images = await _picker.pickMultiImage(
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
      limit: remaining,
    );
    if (images.isEmpty) return;

    final files = <File>[];
    for (final image in images.take(remaining)) {
      files.add(await _prepareImageFile(image));
    }
    if (mounted) {
      setState(() {
        _newPhotoFiles = [..._newPhotoFiles, ...files];
        _saved = false;
      });
    }
  }

  Future<File> _prepareImageFile(XFile image) async {
    final source = File(image.path);
    final dotIndex = image.path.lastIndexOf('.');
    final targetPath = dotIndex == -1
        ? '${image.path}_compressed.jpg'
        : '${image.path.substring(0, dotIndex)}_compressed.jpg';

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
    } catch (_) {}
    return source;
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
    return date.isAfter(DateTime.now()) ? null : date;
  }

  int? _selectedAge() {
    final birthDate = _selectedBirthDate();
    if (birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.isBefore(DateTime(now.year, birthDate.month, birthDate.day))) age--;
    return age >= 0 ? age : null;
  }

  ImageProvider? _avatarProvider() {
    if (_avatarFile != null) return FileImage(_avatarFile!);
    final localPath = _currentLocalAvatarPath;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      return FileImage(File(localPath));
    }
    final avatarUrl = _currentAvatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }
    return null;
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

  void _markDirty() {
    if (_saved) {
      setState(() => _saved = false);
    }
  }

  Future<void> _save({bool exitAfterSave = true}) async {
    if (_saving) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    final birthDate = _selectedBirthDate();
    if ((_birthYear != null || _birthMonth != null || _birthDay != null) &&
        birthDate == null) {
      _showMessage('Укажите корректную дату рождения');
      return;
    }
    if (_residenceCity.text.trim().isNotEmpty && _residenceRegion == null) {
      _showMessage('Выберите субъект РФ');
      return;
    }

    final username = _social.normalizeUsername(_username.text);
    if (!_social.isValidUsername(username)) {
      _showMessage('Имя пользователя: 3-24 символа, латиница, цифры и _');
      return;
    }

    setState(() => _saving = true);
    try {
      final available = await _social.isUsernameAvailable(username, user.id);
      if (!available) {
        _showMessage('Такое имя пользователя уже занято');
        return;
      }

      await _sync.saveProfileAndSync(
        userId: user.id,
        profileData: {
          'id': user.id,
          'email': user.email,
          'username': username,
          'name': _normalizeName(_name.text),
          'surname': _normalizeName(_surname.text),
          'birth_date': birthDate?.toIso8601String().split('T').first,
          'residence_city': _capitalizeFirst(_residenceCity.text),
          'residence_region': _residenceRegion,
          'residence_country': 'Россия',
          'bio': _capitalizeFirst(_bio.text),
          'updated_at': DateTime.now().toIso8601String(),
        },
        avatarFile: _avatarFile,
        photoFiles: _newPhotoFiles,
      );

      if (!mounted) return;
      setState(() => _saved = true);
      _showMessage('Сохранено');
      if (exitAfterSave) Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == '23505') {
        _showMessage('Такое имя пользователя уже занято');
      } else if (e.code == 'PGRST204') {
        _showMessage('Примените новую миграцию Supabase и попробуйте снова');
      } else {
        _showMessage('Ошибка: ${e.message}');
      }
    } catch (e) {
      if (mounted) _showMessage('Ошибка: $e');
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

    return WillPopScope(
      onWillPop: () async {
        if (_saving) return false;
        if (!_saved) {
          await _save(exitAfterSave: false);
          return _saved;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Редактировать профиль'),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => _save(exitAfterSave: false),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _saving
                    ? const SizedBox(
                        key: ValueKey('saving'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _saved ? Icons.check_circle : Icons.save_outlined,
                        key: ValueKey(_saved ? 'saved' : 'save'),
                        color: _saved ? Colors.green : null,
                      ),
              ),
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
                    child: _avatarProvider() == null
                        ? const Icon(Icons.camera_alt, size: 30)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildField('Имя', _name, onChanged: (_) => _markDirty()),
              _buildField('Фамилия', _surname, onChanged: (_) => _markDirty()),
              _buildUsernameField(),
              _buildBirthDateFields(_selectedAge()),
              _buildRegionDropdown(),
              _buildCityAutocomplete(),
              _buildField(
                'О себе',
                _bio,
                maxLines: 3,
                onChanged: (_) => _markDirty(),
              ),
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
                      _saved = false;
                    });
                  },
                ),
              ],
            ],
          ),
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
                    if (!_availableDays().contains(_birthDay)) _birthDay = null;
                    _saved = false;
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
                    if (!_availableDays().contains(_birthDay)) _birthDay = null;
                    _saved = false;
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
                  onChanged: (value) => setState(() {
                    _birthDay = value;
                    _saved = false;
                  }),
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
          _saved = false;
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
          return russianCitiesForRegion(
            _residenceRegion,
          ).where((city) => city.toLowerCase().contains(query)).take(8);
        },
        onSelected: (city) {
          _residenceCity.text = city;
          _markDirty();
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            onChanged: (value) {
              _residenceCity.text = value;
              _markDirty();
            },
            decoration: const InputDecoration(
              labelText: 'Город',
              border: OutlineInputBorder(),
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
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        textInputAction: maxLines == 1 ? TextInputAction.next : null,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: _username,
        onChanged: (_) => _markDirty(),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_@]')),
        ],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Имя пользователя',
          hintText: '@sonya_2005',
          prefixIcon: Icon(Icons.alternate_email),
          border: OutlineInputBorder(),
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
