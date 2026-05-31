import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/social_service.dart';
import '../widgets/username_badge.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  final _search = TextEditingController();
  final _social = SocialService.instance;
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _profileResults = [];
  bool _loading = true;
  bool _searching = false;
  int _loadRun = 0;

  @override
  void initState() {
    super.initState();
    _loadChats(showLoading: true);
    _search.addListener(_scheduleSearch);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadChats(showLoading: false),
    );
    if (mounted && _search.text.trim().isNotEmpty) {
      setState(() => _searching = true);
    }
  }

  Future<void> _loadChats({bool showLoading = false}) async {
    final run = ++_loadRun;
    final query = _search.text;
    if (mounted && showLoading) setState(() => _loading = true);
    try {
      final chats = await _social.loadChats(query: query);
      final profiles = query.trim().isEmpty
          ? <Map<String, dynamic>>[]
          : await _social.searchProfiles(query);
      if (!mounted || run != _loadRun) return;
      setState(() {
        _chats = chats;
        _profileResults = profiles;
        _loading = false;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || run != _loadRun) return;
      setState(() {
        _loading = false;
        _searching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить сообщения: $error')),
      );
    }
  }

  Future<void> _deleteChat(String chatId) async {
    await _social.deleteChatForMe(chatId);
    await _loadChats();
  }

  Future<void> _openSelfChat() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    final profile =
        await _social.loadProfile(currentUserId) ??
        {'id': currentUserId, 'username': currentUserId};
    await _openChatWithProfile(Map<String, dynamic>.from(profile));
  }

  Future<void> _openChatWithProfile(Map<String, dynamic> profile) async {
    try {
      final chatId = await _social.openChatWith(profile['id'].toString());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            chatId: chatId,
            otherProfile: Map<String, dynamic>.from(profile),
          ),
        ),
      );
      await _loadChats();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось открыть чат: $error')));
    }
  }

  List<Map<String, dynamic>> _visibleProfileResults() {
    final chatUserIds = _chats
        .map((chat) => (chat['other_profile'] as Map?)?['id']?.toString())
        .whereType<String>()
        .toSet();
    return _profileResults
        .where((profile) => !chatUserIds.contains(profile['id']?.toString()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final extraProfiles = _visibleProfileResults();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Сообщения'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
        actions: [
          IconButton(
            onPressed: _openSelfChat,
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Сообщения себе',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: InkWell(
              onTap: _openSelfChat,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink.shade100),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.pink.shade50,
                      child: const Icon(Icons.bookmark_border),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Сообщения себе',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Поиск по @username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
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
                    onRefresh: () => _loadChats(showLoading: false),
                    child: _chats.isEmpty && extraProfiles.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 160),
                              Center(child: Text('Чатов пока нет')),
                            ],
                          )
                        : ListView.separated(
                            itemCount: _chats.length + extraProfiles.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              if (index >= _chats.length) {
                                final profile =
                                    extraProfiles[index - _chats.length];
                                return _ProfileSearchTile(
                                  profile: profile,
                                  onTap: () => _openChatWithProfile(profile),
                                );
                              }
                              final chat = _chats[index];
                              final profile = Map<String, dynamic>.from(
                                chat['other_profile'] as Map,
                              );
                              final isSelfChat =
                                  chat['user_low'].toString() ==
                                  chat['user_high'].toString();
                              return Dismissible(
                                key: ValueKey(chat['id']),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                onDismissed: (_) =>
                                    _deleteChat(chat['id'].toString()),
                                child: ListTile(
                                  leading: _ChatAvatar(profile: profile),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSelfChat
                                            ? 'Сообщения себе'
                                            : _displayName(profile),
                                      ),
                                      const SizedBox(height: 4),
                                      UsernameBadge(
                                        username: profile['username'],
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _latestText(chat),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _messageCountText(chat, isSelfChat),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    _shortDate(chat['updated_at']),
                                  ),
                                  onTap: () => _openChatWithProfile(profile),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  String _latestText(Map<String, dynamic> chat) {
    final latest = chat['latest_message'];
    if (latest is Map && (latest['body'] ?? '').toString().isNotEmpty) {
      return latest['body'].toString();
    }
    return SocialService.instance.usernameLabel(
      (chat['other_profile'] as Map?)?['username'],
    );
  }

  String _messageCountText(Map<String, dynamic> chat, bool isSelfChat) {
    final myCount = chat['my_message_count'] as int? ?? 0;
    final otherCount = chat['other_message_count'] as int? ?? 0;
    if (isSelfChat) return 'Сообщений: $myCount';
    return 'Пользователь отправил(а): $otherCount';
  }
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.chatId,
    required this.otherProfile,
  });

  final String chatId;
  final Map<String, dynamic> otherProfile;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _message = TextEditingController();
  final _social = SocialService.instance;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _blocked = false;
  bool _sending = false;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  bool get _isSelfChat =>
      widget.otherProfile['id']?.toString() == _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final messages = await _social.loadMessages(widget.chatId);
    final blocked = _isSelfChat
        ? false
        : await _social.isBlocked(widget.otherProfile['id']?.toString() ?? '');
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _blocked = blocked;
      _loading = false;
    });
  }

  Future<void> _send() async {
    if (_blocked || _sending) return;
    final userId = _currentUserId;
    if (userId == null) return;
    final text = _message.text.trim();
    if (text.isEmpty) return;
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pendingMessage = <String, dynamic>{
      'id': pendingId,
      'chat_id': widget.chatId,
      'sender_id': userId,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
      '_pending': true,
    };
    _message.clear();
    setState(() {
      _sending = true;
      _messages = [..._messages, pendingMessage];
    });
    try {
      final saved = await _social.sendMessage(widget.chatId, text);
      if (!mounted) return;
      setState(() {
        if (saved == null) {
          _messages = _messages
              .where((message) => message['id'] != pendingId)
              .toList();
        } else {
          _messages = _messages
              .map((message) => message['id'] == pendingId ? saved : message)
              .toList();
        }
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .where((message) => message['id'] != pendingId)
            .toList();
        _sending = false;
      });
      _message.text = text;
      _message.selection = TextSelection.collapsed(offset: text.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить сообщение: $error')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    await _social.deleteMessageForMe(messageId);
    await _load();
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final controller = TextEditingController(
      text: message['body']?.toString() ?? '',
    );
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Редактировать'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Сообщение'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      await _social.editMessage(message['id'].toString(), text);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить сообщение: $error')),
      );
    }
  }

  Future<void> _showMessageActions(Map<String, dynamic> message) async {
    if (message['_pending'] == true) return;
    final mine = message['sender_id'] == _currentUserId;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Сообщение'),
        children: [
          if (mine)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'edit'),
              child: const Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 12),
                  Text('Редактировать'),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'delete'),
            child: const Row(
              children: [
                Icon(Icons.delete_outline),
                SizedBox(width: 12),
                Text('Удалить у меня'),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (mounted) await _editMessage(message);
    }
    if (action == 'delete') await _deleteMessage(message['id'].toString());
  }

  Future<void> _toggleBlock() async {
    final otherId = widget.otherProfile['id']?.toString();
    if (otherId == null || _isSelfChat) return;
    await _social.toggleBlock(otherId, _blocked);
    await _load();
  }

  Future<void> _clearChat() async {
    await _social.clearChatForMe(widget.chatId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSelfChat
        ? 'Сообщения себе'
        : _displayName(widget.otherProfile);
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3FA),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            _ChatAvatar(profile: widget.otherProfile, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  UsernameBadge(
                    username: widget.otherProfile['username'],
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _toggleBlock();
              if (value == 'clear') _clearChat();
            },
            itemBuilder: (context) => [
              if (!_isSelfChat)
                PopupMenuItem(
                  value: 'block',
                  child: Text(_blocked ? 'Разблокировать' : 'Заблокировать'),
                ),
              const PopupMenuItem(value: 'clear', child: Text('Очистить чат')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _messages.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 160),
                              Center(child: Text('Сообщений пока нет')),
                            ],
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  _messages[_messages.length - 1 - index];
                              final mine =
                                  message['sender_id'] == _currentUserId;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: () =>
                                      _showMessageActions(message),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.76,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? const Color(0xFFDCF7C5)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(message['body']?.toString() ?? ''),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (message['_pending'] == true) ...[
                                              const SizedBox(
                                                width: 11,
                                                height: 11,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            if (message['edited_at'] !=
                                                null) ...[
                                              const Text(
                                                'изменено',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              _shortDate(message['created_at']),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      enabled: !_blocked,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _blocked
                            ? 'Пользователь заблокирован'
                            : 'Сообщение',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed:
                        _blocked || _sending || _message.text.trim().isEmpty
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
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

class _ProfileSearchTile extends StatelessWidget {
  const _ProfileSearchTile({required this.profile, required this.onTap});

  final Map<String, dynamic> profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelf =
        profile['id']?.toString() ==
        Supabase.instance.client.auth.currentUser?.id;
    return ListTile(
      leading: _ChatAvatar(profile: profile),
      title: Text(isSelf ? 'Сообщения себе' : _displayName(profile)),
      subtitle: Align(
        alignment: Alignment.centerLeft,
        child: UsernameBadge(username: profile['username'], compact: true),
      ),
      trailing: const Icon(Icons.chat_bubble_outline),
      onTap: onTap,
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.profile, this.radius = 24});

  final Map<String, dynamic> profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = (profile['avatar_url'] ?? '').toString();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.pink.shade50,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty ? const Icon(Icons.person, color: Colors.pink) : null,
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

String _shortDate(Object? value) {
  final date = DateTime.tryParse((value ?? '').toString())?.toLocal();
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
