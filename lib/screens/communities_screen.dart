import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../blocs/auth/auth_cubit.dart';

const _pink = Color(0xFFEC4899);
const _pinkLight = Color(0xFFFCE7F3);

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _apiService = ApiService();
  List<dynamic> _communities = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;
  // Inline chat state
  Map? _activeChat; // community currently open in chat panel
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _chatLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) _currentUser = state.user;
    _fetchCommunities();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCommunities() async {
    setState(() => _isLoading = true);
    final communities = await _apiService.getCommunities();
    if (mounted)
      setState(() {
        _communities = communities;
        _isLoading = false;
      });
  }

  Future<void> _loadChat(Map community) async {
    setState(() {
      _activeChat = community;
      _chatLoading = true;
      _messages = [];
    });
    final msgs = await _apiService.getCommunityMessages(community['id']);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _chatLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _closeChat() => setState(() {
    _activeChat = null;
    _messages = [];
  });

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _activeChat == null) return;
    setState(() => _isSending = true);
    _messageCtrl.clear();
    // Optimistic: add message immediately
    final myUsername = _currentUser?['username'] ?? 'Me';
    final myId = _currentUser?['id'];
    setState(() {
      _messages = [
        ..._messages,
        {
          'content': text,
          'sender': myId,
          'sender_username': myUsername,
          'sent_at': DateTime.now().toIso8601String(),
        },
      ];
    });
    _scrollToBottom();
    final success = await _apiService.sendCommunityMessage(
      _activeChat!['id'],
      text,
    );
    if (success) {
      // Refresh to get server-side IDs
      final msgs = await _apiService.getCommunityMessages(_activeChat!['id']);
      if (mounted) setState(() => _messages = msgs);
      _scrollToBottom();
    }
    if (mounted) setState(() => _isSending = false);
  }

  void _showCreateCommunityDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _pinkLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.group_add, color: _pink, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Create Community'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Community Name *',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _pink, width: 2),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _pink, width: 2),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final success = await _apiService.createCommunity({
                'name': nameCtrl.text,
                'description': descCtrl.text,
              });
              Navigator.pop(ctx);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Community created!')),
                );
                _fetchCommunities();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _currentUser?['role'] ?? 'STUDENT';
    final canCreate = [
      'ADMIN',
      'ALUMNI',
      'FACULTY',
      'VOLUNTEER',
    ].contains(role);
    final myId = _currentUser?['id'];
    final myName = _currentUser?['username'] ?? 'Me';

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: _pink))
        : Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // — Community list (left panel) —
                Expanded(
                  flex: _activeChat != null ? 2 : 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _pinkLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.groups,
                                  color: _pink,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Communities',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const Text(
                                    'Connect & collaborate',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (canCreate)
                            ElevatedButton.icon(
                              onPressed: _showCreateCommunityDialog,
                              icon: const Icon(Icons.group_add_outlined),
                              label: const Text('Create'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _pink,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _communities.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.groups_outlined,
                                      size: 64,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No communities yet. Create one!',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _communities.length,
                                itemBuilder: (ctx, index) {
                                  final community = _communities[index];
                                  final isActive =
                                      _activeChat != null &&
                                      _activeChat!['id'] == community['id'];
                                  return GestureDetector(
                                    onTap: () => _loadChat(community),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? _pinkLight
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isActive
                                              ? _pink
                                              : Colors.grey.shade100,
                                        ),
                                        boxShadow: isActive
                                            ? [
                                                BoxShadow(
                                                  color: _pink.withOpacity(
                                                    0.15,
                                                  ),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? _pink
                                                    : _pinkLight,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                (community['name'] ?? '?')[0]
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: isActive
                                                      ? Colors.white
                                                      : _pink,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    community['name'] ?? '',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color: isActive
                                                          ? _pink
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                  if ((community['description'] ??
                                                          '')
                                                      .isNotEmpty)
                                                    Text(
                                                      community['description'],
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .chat_bubble_outline,
                                                        size: 12,
                                                        color: Colors
                                                            .grey
                                                            .shade400,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${community['message_count'] ?? 0} messages',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey
                                                              .shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              isActive
                                                  ? Icons.chevron_right
                                                  : Icons.arrow_forward_ios,
                                              size: 16,
                                              color: isActive
                                                  ? _pink
                                                  : Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // — Inline Chat Panel (right panel, shown when a community is selected) —
                if (_activeChat != null) ...[
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _pink.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: _pink.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Chat header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              color: _pink,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.25,
                                  ),
                                  radius: 18,
                                  child: Text(
                                    (_activeChat!['name'] ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _activeChat!['name'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '${_messages.length} messages • ${_activeChat!['member_count'] ?? 0} members',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_activeChat!['is_member'] == false)
                                  ElevatedButton(
                                    onPressed: () async {
                                      final success = await _apiService
                                          .joinCommunity(_activeChat!['id']);
                                      if (success) {
                                        _fetchCommunities();
                                        final msgs = await _apiService
                                            .getCommunityMessages(
                                              _activeChat!['id'],
                                            );
                                        setState(() {
                                          _activeChat!['is_member'] = true;
                                          _activeChat!['member_count'] =
                                              (_activeChat!['member_count'] ??
                                                  0) +
                                              1;
                                          _messages = msgs;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: _pink,
                                    ),
                                    child: const Text('Join'),
                                  )
                                else
                                  IconButton(
                                    onPressed: _closeChat,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Close chat',
                                  ),
                              ],
                            ),
                          ),

                          // Messages
                          Expanded(
                            child: _chatLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: _pink,
                                    ),
                                  )
                                : _messages.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 48,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'No messages yet. Say hello!',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollCtrl,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _messages.length,
                                    itemBuilder: (ctx, i) {
                                      final msg = _messages[i];
                                      final isMe =
                                          msg['sender'] == myId ||
                                          msg['sender_username'] == myName;
                                      return Align(
                                        alignment: isMe
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe ? _pink : _pinkLight,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                14,
                                              ),
                                              topRight: const Radius.circular(
                                                14,
                                              ),
                                              bottomLeft: Radius.circular(
                                                isMe ? 14 : 2,
                                              ),
                                              bottomRight: Radius.circular(
                                                isMe ? 2 : 14,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (!isMe)
                                                Text(
                                                  msg['sender_username'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: _pink,
                                                  ),
                                                ),
                                              Text(
                                                msg['content'] ?? '',
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          // Input bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: _pink.withOpacity(0.15)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Type a message...',
                                      filled: true,
                                      fillColor: _pinkLight,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(
                                          color: _pink,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                    maxLines: null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _isSending
                                    ? const SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _pink,
                                        ),
                                      )
                                    : IconButton.filled(
                                        onPressed: _sendMessage,
                                        icon: const Icon(Icons.send_rounded),
                                        style: IconButton.styleFrom(
                                          backgroundColor: _pink,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
  }
}
