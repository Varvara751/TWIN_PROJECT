import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/social_service.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  final _search = TextEditingController();
  final _social = SocialService.instance;
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _search.addListener(_loadChats);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _social.loadChats(query: _search.text);
      if (mounted) {
        setState(() {
          _chats = chats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteChat(String chatId) async {
    await _social.deleteChatForMe(chatId);
    await _loadChats();
  }

  Future<void> _openSelfChat() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    final chatId = await _social.openChatWith(currentUserId);
    final profile =
        await _social.loadProfile(currentUserId) ??
        {'id': currentUserId, 'username': currentUserId};
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
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                    onRefresh: _loadChats,
                    child: _chats.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 160),
                              Center(child: Text('Чатов пока нет')),
                            ],
                          )
                        : ListView.separated(
                            itemCount: _chats.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
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
                                  title: Text(
                                    isSelfChat
                                        ? 'Сообщения себе'
                                        : _displayName(profile),
                                  ),
                                  subtitle: Text(
                                    _latestText(chat),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(_shortDate(chat['updated_at'])),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatThreadScreen(
                                          chatId: chat['id'].toString(),
                                          otherProfile: profile,
                                        ),
                                      ),
                                    );
                                    _loadChats();
                                  },
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
    if (mounted) {
      setState(() {
        _messages = messages;
        _blocked = blocked;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_blocked) return;
    final text = _message.text.trim();
    if (text.isEmpty) return;
    _message.clear();
    await _social.sendMessage(widget.chatId, text);
    await _load();
  }

  Future<void> _deleteMessage(String messageId) async {
    await _social.deleteMessageForMe(messageId);
    await _load();
  }

  Future<void> _toggleBlock() async {
    final otherId = widget.otherProfile['id']?.toString();
    if (otherId == null || _isSelfChat) return;
    await _social.toggleBlock(otherId, _blocked);
    await _load();
  }

  Future<void> _deleteChat() async {
    await _social.deleteChatForMe(widget.chatId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSelfChat ? 'Сообщения себе' : _displayName(widget.otherProfile);
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
                  Text(
                    SocialService.instance.usernameLabel(
                      widget.otherProfile['username'],
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              if (value == 'delete') _deleteChat();
            },
            itemBuilder: (context) => [
              if (!_isSelfChat)
                PopupMenuItem(
                  value: 'block',
                  child: Text(_blocked ? 'Разблокировать' : 'Заблокировать'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Удалить чат')),
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
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, reverseIndex) {
                        final message =
                            _messages[_messages.length - 1 - reverseIndex];
                        final mine = message['sender_id'] == _currentUserId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () =>
                                _deleteMessage(message['id'].toString()),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.76,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFDCF7C5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(message['body']?.toString() ?? ''),
                                  const SizedBox(height: 4),
                                  Text(
                                    _shortDate(message['created_at']),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
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
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _blocked ? null : _send,
                    icon: const Icon(Icons.send),
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
  final date = DateTime.tryParse((value ?? '').toString());
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
