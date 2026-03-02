import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 18),
            ),
            if (!isMobile) const SizedBox(width: 10),
            if (!isMobile)
              const Text(
                'Alumni Portal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => context.go('/login'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.primary),
              foregroundColor: theme.colorScheme.primary,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
            ),
            child: const Text('Login'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
            ),
            child: const Text('Register'),
          ),
          SizedBox(width: isMobile ? 8 : 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 40 : 80,
                horizontal: 24,
              ),
              color: theme.colorScheme.primary.withOpacity(0.05),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hub, size: isMobile ? 60 : 80, color: Colors.blue),
                  SizedBox(height: isMobile ? 16 : 24),
                  Text(
                    'Welcome to the Alumni Portal',
                    style:
                        (isMobile
                                ? theme.textTheme.headlineSmall
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connect with graduates, find job opportunities, and engage with your community.',
                    style:
                        (isMobile
                                ? theme.textTheme.bodyLarge
                                : theme.textTheme.titleMedium)
                            ?.copyWith(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.login),
                        label: const Text('Login'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          backgroundColor: Colors.white,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/register'),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Join Now'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Features Section
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 40 : 60,
                horizontal: isMobile ? 16 : 24,
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _FeatureCard(
                    icon: Icons.work,
                    title: 'Job Board',
                    description:
                        'Find and post exclusive job opportunities within the alumni network.',
                    isMobile: isMobile,
                  ),
                  _FeatureCard(
                    icon: Icons.forum,
                    title: 'Communities',
                    description:
                        'Join interest-based groups and chat with like-minded individuals.',
                    isMobile: isMobile,
                  ),
                  _FeatureCard(
                    icon: Icons.volunteer_activism,
                    title: 'Donations',
                    description:
                        'Give back to your alma mater and track fund allocations transparently.',
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              color: Colors.grey.shade900,
              child: const Text(
                '© 2026 Alumni Portal. All rights reserved.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isMobile;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? double.infinity : 300,
      constraints: const BoxConstraints(maxWidth: 350),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
