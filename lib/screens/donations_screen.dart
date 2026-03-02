import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DonationsScreen extends StatefulWidget {
  final Map<String, dynamic>?
  user; // Contains role info like ADMIN, ALUMNI etc.
  const DonationsScreen({super.key, required this.user});

  @override
  _DonationsScreenState createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _donations = [];
  List<dynamic> _fundAllocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final donations = await _apiService.getDonations();
      final funds = await _apiService.getFundAllocations();
      setState(() {
        _donations = donations;
        _fundAllocations = funds;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load donations/funds: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveDonation(int id) async {
    final success = await _apiService.approveDonation(id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation approved successfully!')),
      );
      _fetchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve donation.')),
      );
    }
  }

  void _showDonateDialog() {
    final amountController = TextEditingController();
    final purposeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a Donation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (\$)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: purposeController,
              decoration: const InputDecoration(
                labelText: 'Purpose (Optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isEmpty) return;
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;

              final success = await _apiService.makeDonation({
                'amount': amount,
                'purpose': purposeController.text,
              });

              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Donation submitted! Awaiting approval.'),
                  ),
                );
                _fetchData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to submit donation.')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showAllocateFundDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allocate Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (\$)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || amountController.text.isEmpty)
                return;
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;

              final success = await _apiService.allocateFund({
                'title': titleController.text,
                'description': descController.text,
                'amount': amount,
              });

              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funds allocated successfully!'),
                  ),
                );
                _fetchData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to allocate funds.')),
                );
              }
            },
            child: const Text('Allocate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin =
        widget.user?['role'] == 'ADMIN' || widget.user?['role'] == 'VOLUNTEER';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
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
                      color: const Color(0xFFEC4899).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      color: Color(0xFFEC4899),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Donations & Funds',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                      ),
                      Text(
                        'Support our community',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showDonateDialog,
                    icon: const Icon(Icons.favorite),
                    label: const Text('Donate Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (isAdmin)
                    ElevatedButton.icon(
                      onPressed: _showAllocateFundDialog,
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Allocate Funds'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donations List
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Donations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _donations.isEmpty
                                ? const Center(
                                    child: Text('No donations found.'),
                                  )
                                : ListView.separated(
                                    itemCount: _donations.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(),
                                    itemBuilder: (context, index) {
                                      final donation = _donations[index];
                                      final isApproved =
                                          donation['is_approved'];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isApproved
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          child: Icon(
                                            isApproved
                                                ? Icons.check_circle
                                                : Icons.pending,
                                            color: isApproved
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                        title: Text(
                                          '\$${donation['amount']} from ${donation['donor_username']}',
                                        ),
                                        subtitle: Text(
                                          donation['purpose'] ??
                                              'General Purpose',
                                        ),
                                        trailing: (!isApproved && isAdmin)
                                            ? ElevatedButton(
                                                onPressed: () =>
                                                    _approveDonation(
                                                      donation['id'],
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF10B981,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Approve',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Fund Allocations List
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fund Allocations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _fundAllocations.isEmpty
                                ? const Center(
                                    child: Text('No funds allocated yet.'),
                                  )
                                : ListView.separated(
                                    itemCount: _fundAllocations.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(),
                                    itemBuilder: (context, index) {
                                      final fund = _fundAllocations[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.blue.shade100,
                                          child: const Icon(
                                            Icons.outbound,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        title: Text(fund['title']),
                                        subtitle: Text(
                                          '${fund['description']}\nAllocated by: ${fund['allocated_by_username']}',
                                        ),
                                        trailing: Text(
                                          '-\$${fund['amount']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                            fontSize: 16,
                                          ),
                                        ),
                                        isThreeLine: true,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
