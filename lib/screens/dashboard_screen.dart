import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_cubit.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;

  // Derived counts
  int _totalAlumni = 0;
  int _totalStudents = 0;
  int _activeJobs = 0;
  int _totalCommunities = 0;
  int _pendingApprovals = 0;
  int _pendingDonations = 0;
  int _totalEvents = 0;
  int _totalNotices = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final role = _role(context);
      final isAdminOrStaff = ['ADMIN', 'FACULTY', 'VOLUNTEER'].contains(role);

      if (isAdminOrStaff) {
        // Fetch all in parallel
        final results = await Future.wait([
          _apiService.getDashboardStats(),
          _apiService.getPendingRequests(),
        ]);

        final stats = results[0];
        final pending = results[1];

        if (mounted) {
          setState(() {
            _totalAlumni = stats['total_alumni'] ?? 0;
            _totalStudents = stats['total_students'] ?? 0;
            _activeJobs = stats['active_jobs'] ?? 0;
            _totalCommunities = stats['total_communities'] ?? 0;
            _totalEvents = stats['total_events'] ?? 0;
            _totalNotices = stats['total_notices'] ?? 0;

            _pendingApprovals =
                (pending['pending_users'] as List?)?.length ?? 0;
            _pendingDonations =
                (pending['pending_donations'] as List?)?.length ?? 0;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _role(BuildContext context) {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) return state.user['role'] ?? 'STUDENT';
    return 'STUDENT';
  }

  Map<String, dynamic>? _currentUser(BuildContext context) {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) return state.user;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final role = _role(context);
    final user = _currentUser(context);
    final isAdmin = role == 'ADMIN';
    final isAdminOrStaff = ['ADMIN', 'FACULTY', 'VOLUNTEER'].contains(role);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isAdmin) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dashboard,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Overview',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Alumni Portal Management Dashboard',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ] else ...[
            // Personalized greeting for non-admin
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    (user?['first_name'] ?? user?['username'] ?? '?')[0]
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${user?['first_name'] ?? user?['username'] ?? 'there'}! 👋',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      role == 'FACULTY'
                          ? 'Faculty Member'
                          : role == 'VOLUNTEER'
                          ? 'Student Volunteer'
                          : role == 'STUDENT'
                          ? 'Student'
                          : 'Alumni',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // Stats grid (Admin/Faculty/Volunteer)
          if (isAdminOrStaff) ...[
            if (isAdmin) ...[
              // Full admin stats in two rows
              _SectionLabel(label: 'Platform Overview'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Total Alumni',
                    value: '$_totalAlumni',
                    icon: Icons.school,
                    color: Colors.blue,
                    onTap: () => context.go('/directory'),
                  ),
                  _StatCard(
                    title: 'Total Students',
                    value: '$_totalStudents',
                    icon: Icons.people,
                    color: Colors.teal,
                    onTap: () => context.go('/directory'),
                  ),
                  _StatCard(
                    title: 'Active Jobs',
                    value: '$_activeJobs',
                    icon: Icons.work,
                    color: Colors.orange,
                    onTap: () => context.go('/jobs'),
                  ),
                  _StatCard(
                    title: 'Communities',
                    value: '$_totalCommunities',
                    icon: Icons.forum,
                    color: Colors.purple,
                    onTap: () => context.go('/communities'),
                  ),
                  _StatCard(
                    title: 'Events',
                    value: '$_totalEvents',
                    icon: Icons.event,
                    color: Colors.cyan,
                    onTap: () => context.go('/events'),
                  ),
                  _StatCard(
                    title: 'Notices',
                    value: '$_totalNotices',
                    icon: Icons.campaign,
                    color: Colors.indigo,
                    onTap: () => context.go('/notices'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel(label: 'Pending Actions'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Pending Approvals',
                    value: '$_pendingApprovals',
                    icon: Icons.person_add,
                    color: _pendingApprovals > 0 ? Colors.red : Colors.green,
                    badge: _pendingApprovals > 0,
                    onTap: () => context.go('/admin/users'),
                  ),
                  _StatCard(
                    title: 'Pending Donations',
                    value: '$_pendingDonations',
                    icon: Icons.volunteer_activism,
                    color: _pendingDonations > 0 ? Colors.orange : Colors.green,
                    badge: _pendingDonations > 0,
                    onTap: () => context.go('/donations'),
                  ),
                ],
              ),
            ] else ...[
              // Faculty / Volunteer: show pending approvals
              _SectionLabel(label: 'Your Overview'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Pending Approvals',
                    value: '$_pendingApprovals',
                    icon: Icons.person_add,
                    color: _pendingApprovals > 0 ? Colors.red : Colors.green,
                    badge: _pendingApprovals > 0,
                    onTap: () => context.go('/admin/users'),
                  ),
                  _StatCard(
                    title: 'Active Jobs',
                    value: '$_activeJobs',
                    icon: Icons.work,
                    color: Colors.orange,
                    onTap: () => context.go('/jobs'),
                  ),
                  _StatCard(
                    title: 'Communities',
                    value: '$_totalCommunities',
                    icon: Icons.forum,
                    color: Colors.purple,
                    onTap: () => context.go('/communities'),
                  ),
                ],
              ),
            ],
          ] else ...[
            // Student / Alumni quick links
            const SizedBox(height: 8),
            Text(
              'What would you like to do today?',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _QuickLink(
                  label: 'Browse Jobs',
                  icon: Icons.work_outline,
                  route: '/jobs',
                ),
                _QuickLink(
                  label: 'Communities',
                  icon: Icons.forum_outlined,
                  route: '/communities',
                ),
                _QuickLink(
                  label: 'Events',
                  icon: Icons.event_outlined,
                  route: '/events',
                ),
                _QuickLink(
                  label: 'Notice Board',
                  icon: Icons.campaign_outlined,
                  route: '/notices',
                ),
                _QuickLink(
                  label: 'Donations',
                  icon: Icons.volunteer_activism_outlined,
                  route: '/donations',
                ),
                _QuickLink(
                  label: 'Alumnis',
                  icon: Icons.people_outline,
                  route: '/directory',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool badge;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.badge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: badge ? color.withOpacity(0.5) : Colors.grey.shade100,
              width: badge ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  if (badge)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;
  const _QuickLink({
    required this.label,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Container(
          width: 155,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
