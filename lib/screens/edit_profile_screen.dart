import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_constants.dart';

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
        .from(tableName)
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
    if (image == null) return;

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

      final profileData = {
        'id': user.id,
        'email': user.email,
        'name': _name.text,
        'surname': _surname.text,
        'age': int.tryParse(_age.text),
        'city': _city.text,
        'country': _country.text,
        'bio': _bio.text,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (avatarUrl != null) {
        profileData['avatar_url'] = avatarUrl;
      }

      await Supabase.instance.client.from(tableName).upsert(profileData);

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
