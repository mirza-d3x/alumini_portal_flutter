// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../blocs/auth/auth_cubit.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _apiService = ApiService();
  List<dynamic> users = [];
  bool isLoading = true;
  String _filter = 'ALL'; // ALL, PENDING, APPROVED, BLOCKED

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final fetchedUsers = await _apiService.getUsers();
      if (mounted)
        setState(() {
          users = fetchedUsers;
          isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<dynamic> get _filteredUsers {
    final curId = _currentUserId;
    final otherUsers = curId != null
        ? users.where((u) => u['id'] != curId).toList()
        : users;
    switch (_filter) {
      case 'PENDING':
        return otherUsers.where((u) => u['is_approved'] != true).toList();
      case 'APPROVED':
        return otherUsers
            .where((u) => u['is_approved'] == true && u['is_active'] != false)
            .toList();
      case 'BLOCKED':
        return otherUsers.where((u) => u['is_active'] == false).toList();
      default:
        return otherUsers;
    }
  }

  // Get current user role
  String get _currentRole {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) return state.user['role'] ?? 'STUDENT';
    return 'STUDENT';
  }

  int? get _currentUserId {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) return state.user['id'];
    return null;
  }

  bool get _isAdmin => _currentRole == 'ADMIN';

  void _viewIdCard(String? idCardUrl, Map user) {
    if (idCardUrl == null || idCardUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ID card uploaded for this user.')),
      );
      return;
    }

    final isPdf = idCardUrl.toLowerCase().contains('.pdf');
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
        .trim();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.badge, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ID Card — $name (@${user['username']})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Flexible(
                child: isPdf
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'PDF Document',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  html.window.open(idCardUrl, '_blank'),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open PDF in New Tab'),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            idCardUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (ctx, err, _) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                const Text('Could not load image.'),
                                TextButton.icon(
                                  onPressed: () =>
                                      html.window.open(idCardUrl, '_blank'),
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Open in browser'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => html.window.open(idCardUrl, '_blank'),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Open / Download'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveUser(int userId) async {
    final message = await _apiService.approveUser(userId);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      _fetchUsers();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process approval.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changeRole(int userId, String currentRole) {
    String selectedRole = currentRole;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.manage_accounts, color: Colors.blue, size: 24),
            const SizedBox(width: 10),
            const Text('Change Role'),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            initialValue: selectedRole,
            items: const [
              DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
              DropdownMenuItem(
                value: 'VOLUNTEER',
                child: Text('Volunteer Student'),
              ),
            ],
            onChanged: (val) {
              if (val != null) selectedRole = val;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _apiService.changeUserRole(
                userId,
                selectedRole,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Role updated!')));
                _fetchUsers();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(int userId, bool currentlyBlocked) async {
    final success = currentlyBlocked
        ? await _apiService.unblockUser(userId)
        : await _apiService.blockUser(userId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyBlocked ? 'User unblocked.' : 'User blocked.'),
        ),
      );
      _fetchUsers();
    }
  }

  Future<void> _deleteUser(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 24),
            const SizedBox(width: 10),
            const Text('Delete User'),
          ],
        ),
        content: const Text(
          'This will permanently delete this user account. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await _apiService.deleteUser(userId);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User deleted.')));
        _fetchUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredUsers;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('User Management', style: theme.textTheme.headlineSmall),
              IconButton(
                onPressed: _fetchUsers,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter chips
          Wrap(
            spacing: 8,
            children: ['ALL', 'PENDING', 'APPROVED', 'BLOCKED']
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(child: Text('No $_filter users found.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final u = filtered[index];
                      final userId = u['id'] ?? 0;
                      final isBlocked = u['is_active'] == false;
                      final isPending = u['is_approved'] != true;
                      final role = u['role'] ?? 'STUDENT';
                      final profile = u['profile'] ?? {};
                      final String? _extractedIdCard =
                          profile['id_card'] ??
                          profile['id_card_url'] ??
                          u['id_card_url'];
                      final String? _extractedProfilePic =
                          profile['profile_picture_url'] ??
                          u['profile_picture_url'];

                      final hasIdCard =
                          _extractedIdCard != null &&
                          _extractedIdCard.isNotEmpty;
                      final name =
                          '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                              .trim();
                      final statusColor = isPending
                          ? Colors.orange
                          : isBlocked
                          ? Colors.red
                          : Colors.green;
                      final statusText = isPending
                          ? 'Pending'
                          : isBlocked
                          ? 'Blocked'
                          : 'Approved';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary
                                        .withOpacity(0.15),
                                    backgroundImage:
                                        _extractedProfilePic != null &&
                                            _extractedProfilePic.isNotEmpty
                                        ? NetworkImage(_extractedProfilePic)
                                        : null,
                                    child:
                                        _extractedProfilePic != null &&
                                            _extractedProfilePic.isNotEmpty
                                        ? null
                                        : Text(
                                            (name.isNotEmpty
                                                    ? name[0]
                                                    : u['username']?[0] ?? '?')
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isNotEmpty
                                              ? name
                                              : u['username'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          '@${u['username']} · ${u['email'] ?? ''}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Role chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      role,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Action buttons row
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  // ID card button — visible to all who can see this screen
                                  if (hasIdCard ||
                                      (role == 'ALUMNI' || role == 'STUDENT'))
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _viewIdCard(_extractedIdCard, u),
                                      icon: Icon(
                                        hasIdCard
                                            ? Icons.badge
                                            : Icons.badge_outlined,
                                        size: 16,
                                        color: hasIdCard
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                      label: Text(
                                        hasIdCard
                                            ? 'View ID Card'
                                            : 'No ID Card',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: hasIdCard
                                              ? Colors.blue
                                              : Colors.grey,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: hasIdCard
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  // Approve button (Faculty+Admin for pending users)
                                  if (isPending)
                                    ElevatedButton.icon(
                                      onPressed: () => _approveUser(userId),
                                      icon: const Icon(
                                        Icons.check_circle,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Approve',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  // Admin-only actions (and not self)
                                  if (_isAdmin && userId != _currentUserId) ...[
                                    if (role == 'STUDENT' ||
                                        role == 'VOLUNTEER')
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _changeRole(userId, role),
                                        icon: const Icon(
                                          Icons.manage_accounts,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Change Role',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _blockUser(userId, isBlocked),
                                      icon: Icon(
                                        isBlocked
                                            ? Icons.lock_open
                                            : Icons.block,
                                        size: 16,
                                        color: isBlocked
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      label: Text(
                                        isBlocked ? 'Unblock' : 'Block',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isBlocked
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: isBlocked
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _deleteUser(userId),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
