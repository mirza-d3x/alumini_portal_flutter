import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _apiService = ApiService();
  List<dynamic> _profiles = [];
  List<dynamic> _filteredProfiles = [];
  bool _isLoading = true;

  final _searchCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  void _fetchProfiles() async {
    setState(() => _isLoading = true);
    final profiles = await _apiService.getProfiles();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _filteredProfiles = profiles;
        _isLoading = false;
      });
    }
  }

  void _filterProfiles() {
    final query = _searchCtrl.text.toLowerCase();
    final dept = _deptCtrl.text.toLowerCase();
    final year = _yearCtrl.text.toLowerCase();

    setState(() {
      _filteredProfiles = _profiles.where((p) {
        final pUser = p['user'] is Map ? p['user'] : null;
        final fName = p['first_name'] ?? pUser?['first_name'] ?? '';
        final lName = p['last_name'] ?? pUser?['last_name'] ?? '';
        final name = '$fName $lName'.toLowerCase();

        final uName = p['username'] ?? pUser?['username'] ?? '';
        final usernameStr = uName.toString().toLowerCase();
        final d = (p['department'] ?? '').toLowerCase();
        final y = (p['graduation_year'] ?? '').toString().toLowerCase();

        final matchesName =
            query.isEmpty ||
            name.contains(query) ||
            usernameStr.contains(query);
        final matchesDept = dept.isEmpty || d.contains(dept);
        final matchesYear = year.isEmpty || y.contains(year);

        return matchesName && matchesDept && matchesYear;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _deptCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Alumni Directory (${_filteredProfiles.length} found)',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Search Filters
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      SizedBox(
                        width: 250,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => _filterProfiles(),
                          decoration: const InputDecoration(
                            labelText: 'Search by Name/Username',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _deptCtrl,
                          onChanged: (_) => _filterProfiles(),
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            prefixIcon: Icon(Icons.school),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _yearCtrl,
                          onChanged: (_) => _filterProfiles(),
                          decoration: const InputDecoration(
                            labelText: 'Graduation Year',
                            prefixIcon: Icon(Icons.date_range),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _filteredProfiles.isEmpty
                      ? const Center(
                          child: Text('No alumni found matching the criteria.'),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 350,
                                mainAxisExtent: 220,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                              ),
                          itemCount: _filteredProfiles.length,
                          itemBuilder: (context, index) {
                            final profile = _filteredProfiles[index];
                            final pUser = profile['user'] is Map
                                ? profile['user']
                                : null;
                            final fName =
                                profile['first_name'] ??
                                pUser?['first_name'] ??
                                '';
                            final lName =
                                profile['last_name'] ??
                                pUser?['last_name'] ??
                                '';
                            final name = '$fName $lName'.trim();
                            final uName =
                                profile['username'] ?? pUser?['username'];

                            final displayName = name.isNotEmpty
                                ? name
                                : (uName != null &&
                                          uName.toString().trim().isNotEmpty
                                      ? uName
                                      : 'Alumni');

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.15),
                                          backgroundImage:
                                              profile['profile_picture_url'] !=
                                                  null
                                              ? NetworkImage(
                                                  profile['profile_picture_url'],
                                                )
                                              : null,
                                          child:
                                              profile['profile_picture_url'] !=
                                                  null
                                              ? null
                                              : Text(
                                                  displayName.isNotEmpty
                                                      ? displayName[0]
                                                            .toUpperCase()
                                                      : 'A',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                uName != null &&
                                                        uName
                                                            .toString()
                                                            .isNotEmpty
                                                    ? '@$uName'
                                                    : '',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    if (profile['department'] != null &&
                                        profile['department']
                                            .toString()
                                            .isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.business,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              profile['department'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 6),
                                    if (profile['current_company'] != null &&
                                        profile['current_company']
                                            .toString()
                                            .isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.work,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              profile['current_company'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 6),
                                    if (profile['graduation_year'] != null)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.school,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Class of ${profile['graduation_year']}',
                                          ),
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
