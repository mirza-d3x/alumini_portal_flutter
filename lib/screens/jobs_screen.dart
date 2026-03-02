import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../blocs/auth/auth_cubit.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _apiService = ApiService();
  List<dynamic> _jobs = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchJobs();
  }

  void _loadUser() {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      _currentUser = state.user;
    }
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    final jobs = await _apiService.getJobs();
    if (mounted)
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
  }

  Future<void> _deleteJob(int jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text(
          'Are you sure you want to delete this job posting?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await _apiService.deleteJob(jobId);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Job deleted.')));
        _fetchJobs();
      }
    }
  }

  void _showPostJobDialog() {
    final titleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String jobType = 'FULL_TIME';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Post a Job'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Job Title *',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Company Name *',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location (City/Remote)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: jobType,
                      decoration: const InputDecoration(labelText: 'Job Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'FULL_TIME',
                          child: Text('Full Time'),
                        ),
                        DropdownMenuItem(
                          value: 'PART_TIME',
                          child: Text('Part Time'),
                        ),
                        DropdownMenuItem(
                          value: 'INTERNSHIP',
                          child: Text('Internship'),
                        ),
                        DropdownMenuItem(
                          value: 'CONTRACT',
                          child: Text('Contract'),
                        ),
                        DropdownMenuItem(
                          value: 'REMOTE',
                          child: Text('Remote'),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => jobType = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Job Description *',
                      ),
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
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
                final success = await _apiService.createJob(
                  title: titleCtrl.text,
                  companyName: companyCtrl.text,
                  location: locationCtrl.text,
                  jobType: jobType,
                  description: descCtrl.text,
                );
                Navigator.pop(ctx);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Job posted successfully!')),
                  );
                  _fetchJobs();
                }
              },
              child: const Text('Post Job'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _currentUser?['role'] ?? 'STUDENT';
    final userId = _currentUser?['id'];
    final canPost =
        role != 'STUDENT'; // Alumni, Faculty, Volunteer, and Admin can post
    final isAdminOrVolunteer = role == 'ADMIN' || role == 'VOLUNTEER';

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Job Opportunities',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (canPost)
                      ElevatedButton.icon(
                        onPressed: _showPostJobDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Post a Job'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _jobs.isEmpty
                      ? const Center(child: Text('No jobs posted yet.'))
                      : ListView.builder(
                          itemCount: _jobs.length,
                          itemBuilder: (context, index) {
                            final job = _jobs[index];
                            final isOwner = job['posted_by'] == userId;
                            final canDelete = isAdminOrVolunteer || isOwner;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                job['title'] ?? '',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                job['company'] ??
                                                    'Company not specified',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (canDelete)
                                          IconButton(
                                            onPressed: () =>
                                                _deleteJob(job['id']),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            tooltip: 'Delete Job',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (job['location'] != null &&
                                            job['location'].isNotEmpty) ...[
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            job['location'],
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            (job['job_type'] ?? 'FULL_TIME')
                                                .replaceAll('_', ' '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Posted by ${job['posted_by_name'] ?? job['posted_by_username'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      job['description'] ??
                                          'No description provided.',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton(
                                        onPressed: () => _showJobDetails(job),
                                        child: const Text('View Details'),
                                      ),
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

  void _showJobDetails(Map job) {
    bool isApplying = false;
    final resumeCtrl = TextEditingController();
    final coverCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(job['title'] ?? ''),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow(Icons.business, job['company'] ?? 'N/A'),
                  _detailRow(
                    Icons.location_on_outlined,
                    job['location'] != null && job['location'].isNotEmpty
                        ? job['location']
                        : 'N/A',
                  ),
                  _detailRow(
                    Icons.work_outline,
                    (job['job_type'] ?? '').replaceAll('_', ' '),
                  ),
                  _detailRow(
                    Icons.person_outline,
                    'Posted by ${job['posted_by_name'] ?? job['posted_by_username'] ?? ''}',
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(job['description'] ?? ''),

                  if (isApplying) ...[
                    const Divider(height: 32),
                    const Text(
                      'Apply for this position',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: resumeCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Resume Link (e.g., Google Drive / LinkedIn)',
                        hintText: 'https://...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: coverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cover Letter (Optional)',
                      ),
                      maxLines: 4,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (isApplying) ...[
              TextButton(
                onPressed: () => setDialogState(() => isApplying = false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final link = resumeCtrl.text.trim();
                  if (link.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a resume link.'),
                      ),
                    );
                    return;
                  }
                  final success = await _apiService.applyForJob(
                    jobId: job['id'],
                    resumeLink: link,
                    coverLetter: coverCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Application submitted successfully!'),
                      ),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to submit application.'),
                      ),
                    );
                  }
                },
                child: const Text('Submit Application'),
              ),
            ] else ...[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              // Show apply button if not the owner
              if (job['posted_by'] != _currentUser?['id'])
                ElevatedButton(
                  onPressed: () => setDialogState(() => isApplying = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Now'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
}
