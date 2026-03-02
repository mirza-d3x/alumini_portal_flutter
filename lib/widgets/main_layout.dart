import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../blocs/auth/auth_cubit.dart';
import '../services/api_service.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final ApiService _api = ApiService();

  // Notification data
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _loadingNotifs = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _panelOpen = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNotifications();
      // Start polling every 10 seconds for real-time updates
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _fetchNotifications();
      });
    });
  }

  String _userRole(BuildContext context) {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) return state.user['role'] ?? 'STUDENT';
    return 'STUDENT';
  }

  Future<void> _fetchNotifications() async {
    if (_loadingNotifs) return;
    setState(() => _loadingNotifs = true);

    final notifs = <Map<String, dynamic>>[];
    try {
      final role = _userRole(context);
      final isAdmin = role == 'ADMIN';
      final canApprove = ['ADMIN', 'FACULTY', 'VOLUNTEER'].contains(role);

      if (canApprove) {
        // Pending user approvals
        final users = await _api.getUsers();
        final pending = users.where((u) => u['is_approved'] != true).toList();
        for (final u in pending) {
          notifs.add({
            'type': 'approval',
            'icon': Icons.person_add_outlined,
            'color': Colors.orange,
            'title': 'Pending Approval',
            'body':
                '${u['first_name'] ?? ''} ${u['last_name'] ?? ''} (@${u['username']}) — ${u['role']}',
            'route': '/admin/users',
            'time': u['approved_at'] ?? '',
          });
        }
      }

      if (isAdmin) {
        // Pending donations
        final donations = await _api.getDonations();
        final pending = donations
            .where((d) => d['is_approved'] != true)
            .toList();
        for (final d in pending) {
          notifs.add({
            'type': 'donation',
            'icon': Icons.volunteer_activism,
            'color': Colors.green,
            'title': 'Pending Donation',
            'body':
                '${d['donor_username'] ?? 'Someone'} donated ₹${d['amount']} — ${d['purpose'] ?? ''}',
            'route': '/donations',
            'time': d['created_at'] ?? '',
          });
        }

        // Latest jobs (last 5)
        final jobs = await _api.getJobs();
        final recent = jobs.take(3).toList();
        for (final j in recent) {
          notifs.add({
            'type': 'job',
            'icon': Icons.work_outline,
            'color': Colors.blue,
            'title': 'New Job Posted',
            'body':
                '${j['title'] ?? ''} at ${j['company_name'] ?? 'Unknown Company'}',
            'route': '/jobs',
            'time': j['posted_at'] ?? '',
          });
        }

        // Latest notices (last 5)
        final posts = await _api.getPosts();
        final recentPosts = posts.take(3).toList();
        for (final p in recentPosts) {
          notifs.add({
            'type': 'notice',
            'icon': Icons.campaign_outlined,
            'color': Colors.purple,
            'title': 'New Notice',
            'body': p['content'] != null
                ? (p['content'].toString().length > 70
                      ? '${p['content'].toString().substring(0, 70)}…'
                      : p['content'].toString())
                : '',
            'route': '/notices',
            'time': p['created_at'] ?? '',
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _notifications = notifs;
        _unreadCount = notifs.length;
        _loadingNotifs = false;
      });
    }
  }

  void _togglePanel() {
    if (_panelOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  void _openPanel() {
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _panelOpen = true;
      _unreadCount = 0;
    });
  }

  void _closePanel() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _panelOpen = false);
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible tap-away barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: _closePanel,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // The panel itself, anchored under the bell icon
          Positioned(
            top: kToolbarHeight + 8,
            right: 60,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: _NotificationPanel(
                notifications: _notifications,
                isLoading: _loadingNotifs,
                onRefresh: () async {
                  _closePanel();
                  await _fetchNotifications();
                  if (mounted) _openPanel();
                },
                onNavigate: (route) {
                  _closePanel();
                  GoRouter.of(context).go(route);
                },
                onClose: _closePanel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;
        final role = user['role'] ?? 'STUDENT';
        final isAdminOrStaff = ['ADMIN', 'VOLUNTEER', 'FACULTY'].contains(role);
        final currentPath = GoRouterState.of(context).uri.toString();
        final firstName = user['first_name'] ?? user['username'] ?? '';

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Alumni Portal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            actions: [
              if (isAdminOrStaff) ...[
                // Notification Bell
                CompositedTransformTarget(
                  link: _layerLink,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Notifications',
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _panelOpen
                                  ? Icons.notifications
                                  : Icons.notifications_outlined,
                              key: ValueKey(_panelOpen),
                            ),
                          ),
                          onPressed: _togglePanel,
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEC4899),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              // User avatar / greeting
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.15),
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      firstName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  _closePanel();
                  context.read<AuthCubit>().logout();
                  context.go('/');
                },
                tooltip: 'Logout',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Persistent Sidebar
              Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  children: [
                    // User info in sidebar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.15),
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                          .trim()
                                          .isNotEmpty
                                      ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                            .trim()
                                      : firstName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    // Nav items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        children: [
                          _buildNavItem(
                            context,
                            'Dashboard',
                            Icons.dashboard_outlined,
                            '/dashboard',
                            currentPath,
                          ),
                          _buildNavItem(
                            context,
                            'Alumnis',
                            Icons.people_outline,
                            '/directory',
                            currentPath,
                          ),
                          _buildNavItem(
                            context,
                            'Job Board',
                            Icons.work_outline,
                            '/jobs',
                            currentPath,
                          ),
                          _buildNavItem(
                            context,
                            'Communities',
                            Icons.forum_outlined,
                            '/communities',
                            currentPath,
                          ),
                          _buildNavItem(
                            context,
                            'Events',
                            Icons.event_outlined,
                            '/events',
                            currentPath,
                          ),
                          _buildNavItem(
                            context,
                            'Notice Board',
                            Icons.campaign_outlined,
                            '/notices',
                            currentPath,
                          ),
                          // Donations — pink accent
                          _buildNavItemColored(
                            context,
                            'Donations',
                            Icons.volunteer_activism,
                            '/donations',
                            currentPath,
                            const Color(0xFFEC4899),
                          ),
                          if (isAdminOrStaff) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Divider(height: 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                bottom: 6,
                              ),
                              child: Text(
                                'Administration',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            _buildNavItem(
                              context,
                              'Manage Users',
                              Icons.admin_panel_settings_outlined,
                              '/admin/users',
                              currentPath,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Main Dynamic Content Area
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    String currentPath,
  ) {
    final isSelected =
        currentPath == route ||
        (route != '/dashboard' && currentPath.startsWith(route));
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? color : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? color : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        selectedTileColor: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          if (!isSelected) context.go(route);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }

  Widget _buildNavItemColored(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    String currentPath,
    Color accentColor,
  ) {
    final isSelected =
        currentPath == route ||
        (route != '/dashboard' && currentPath.startsWith(route));
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? accentColor : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? accentColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        selectedTileColor: accentColor.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          if (!isSelected) context.go(route);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Notification Panel Widget (shown as overlay under bell)
// ─────────────────────────────────────────────────────────
class _NotificationPanel extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final bool isLoading;
  final VoidCallback onRefresh;
  final void Function(String route) onNavigate;
  final VoidCallback onClose;

  const _NotificationPanel({
    required this.notifications,
    required this.isLoading,
    required this.onRefresh,
    required this.onNavigate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Group by type
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final n in notifications) {
      groups.putIfAbsent(n['type'] as String, () => []).add(n);
    }

    final groupOrder = ['approval', 'donation', 'job', 'notice'];
    final groupLabels = {
      'approval': 'Pending Approvals',
      'donation': 'Pending Donations',
      'job': 'Recent Jobs',
      'notice': 'Recent Notices',
    };

    return SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
          // Body
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : notifications.isEmpty
                ? _emptyState()
                : ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final type in groupOrder)
                        if (groups.containsKey(type)) ...[
                          _GroupHeader(
                            label: groupLabels[type]!,
                            count: groups[type]!.length,
                          ),
                          for (final n in groups[type]!)
                            _NotifTile(
                              notif: n,
                              onTap: () => onNavigate(n['route'] as String),
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'All caught up!',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          SizedBox(height: 4),
          Text(
            'No pending items to review.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  const _GroupHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = notif['color'] as Color;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(notif['icon'] as IconData, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif['body'] as String,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
