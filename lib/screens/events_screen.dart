// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../blocs/auth/auth_cubit.dart';

const _pink = Color(0xFFEC4899);
const _pinkLight = Color(0xFFFCE7F3);

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _apiService = ApiService();
  List<dynamic> _events = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) _currentUser = state.user;
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    final events = await _apiService.getEvents();
    if (mounted)
      setState(() {
        _events = events;
        _isLoading = false;
      });
  }

  Future<void> _rsvp(int eventId, bool attending) async {
    final success = await _apiService.rsvpEvent(eventId, attending);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attending
                ? 'RSVP confirmed! See you there.'
                : 'You have cancelled your RSVP.',
          ),
        ),
      );
      _fetchEvents();
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
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
      final success = await _apiService.deleteEvent(eventId);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event deleted.')));
        _fetchEvents();
      }
    }
  }

  void _showPostEventDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final formKey = GlobalKey<FormState>();
    List<int>? imageBytes;
    String? imageFilename;
    String? imagePreviewUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _pinkLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event, color: _pink, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Create Event'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Event Title *',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _pink, width: 2),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _pink, width: 2),
                        ),
                      ),
                      maxLines: 3,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: locationCtrl,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _pink, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                              );
                              if (date != null)
                                setDialogState(() => selectedDate = date);
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              selectedDate == null
                                  ? 'Pick Date *'
                                  : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _pink,
                              side: const BorderSide(color: _pink),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: ctx,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null)
                                setDialogState(() => selectedTime = time);
                            },
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              selectedTime == null
                                  ? 'Pick Time *'
                                  : selectedTime!.format(ctx),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _pink,
                              side: const BorderSide(color: _pink),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Event Poster (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (imagePreviewUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imagePreviewUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setDialogState(() {
                                imageBytes = null;
                                imageFilename = null;
                                imagePreviewUrl = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          final input = html.FileUploadInputElement()
                            ..accept = 'image/*'
                            ..click();
                          input.onChange.listen((_) {
                            if (input.files == null || input.files!.isEmpty)
                              return;
                            final file = input.files!.first;
                            final reader = html.FileReader();
                            reader.readAsArrayBuffer(file);
                            reader.onLoad.listen((_) {
                              final bytes = (reader.result as List<int>);
                              final url = html.Url.createObjectUrlFromBlob(
                                file,
                              );
                              setDialogState(() {
                                imageBytes = bytes;
                                imageFilename = file.name;
                                imagePreviewUrl = url;
                              });
                            });
                          });
                        },
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _pinkLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _pink.withOpacity(0.3)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: _pink,
                                size: 32,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Click to select event poster',
                                style: TextStyle(color: _pink, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
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
                if (!formKey.currentState!.validate() ||
                    selectedDate == null ||
                    selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill all required fields and pick date/time.',
                      ),
                    ),
                  );
                  return;
                }
                final eventDateTime = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );
                final success = await _apiService.createEventWithImage(
                  title: titleCtrl.text,
                  description: descCtrl.text,
                  date: eventDateTime.toIso8601String(),
                  location: locationCtrl.text.isEmpty
                      ? null
                      : locationCtrl.text,
                  imageBytes: imageBytes,
                  imageFilename: imageFilename,
                );
                Navigator.pop(ctx);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event created!')),
                  );
                  _fetchEvents();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Event'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(event['title'] ?? 'Event Details'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event['poster_image_url'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      event['poster_image_url']!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'About Event',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  event['description'] ?? 'No description provided.',
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _currentUser?['role'] ?? 'STUDENT';
    final userId = _currentUser?['id'];
    final isAdminOrVolunteer = role == 'ADMIN' || role == 'VOLUNTEER';
    final canCreateEvent = [
      'ADMIN',
      'ALUMNI',
      'FACULTY',
      'VOLUNTEER',
    ].contains(role);

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: _pink))
        : Padding(
            padding: const EdgeInsets.all(32.0),
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
                            Icons.event,
                            color: _pink,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Events & Calendar',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Upcoming events & RSVPs',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (canCreateEvent)
                      ElevatedButton.icon(
                        onPressed: _showPostEventDialog,
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('Create Event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pink,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No events scheduled yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            final isOwner = event['organizer'] == userId;
                            final canDelete = isAdminOrVolunteer || isOwner;
                            final rsvps = event['rsvps'] as List? ?? [];
                            final userRsvp = rsvps
                                .where((r) => r['user'] == userId)
                                .toList();
                            final isAttending =
                                userRsvp.isNotEmpty &&
                                userRsvp.first['is_attending'] == true;
                            final posterUrl = event['poster_image_url'];

                            DateTime? eventDate;
                            try {
                              eventDate = DateTime.parse(event['date']);
                            } catch (_) {}

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Poster image at the top
                                  if (posterUrl != null)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(14),
                                        topRight: Radius.circular(14),
                                      ),
                                      child: Image.network(
                                        posterUrl,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Date badge (pink)
                                        Container(
                                          width: 64,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _pink,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                eventDate != null
                                                    ? '${eventDate.day}'
                                                    : '--',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                eventDate != null
                                                    ? [
                                                        'Jan',
                                                        'Feb',
                                                        'Mar',
                                                        'Apr',
                                                        'May',
                                                        'Jun',
                                                        'Jul',
                                                        'Aug',
                                                        'Sep',
                                                        'Oct',
                                                        'Nov',
                                                        'Dec',
                                                      ][eventDate.month - 1]
                                                    : '---',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      event['title'] ?? '',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                  ),
                                                  if (canDelete)
                                                    IconButton(
                                                      onPressed: () =>
                                                          _deleteEvent(
                                                            event['id'],
                                                          ),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                        size: 20,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (event['location'] != null &&
                                                  event['location'].isNotEmpty)
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .location_on_outlined,
                                                      size: 14,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      event['location'],
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (eventDate != null)
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.access_time,
                                                      size: 14,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${eventDate.hour.toString().padLeft(2, '0')}:${eventDate.minute.toString().padLeft(2, '0')}',
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              const SizedBox(height: 8),
                                              Text(
                                                event['description'] ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              OutlinedButton(
                                                onPressed: () =>
                                                    _showEventDetails(event),
                                                style: OutlinedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'View Details',
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Text(
                                                    '${rsvps.where((r) => r['is_attending'] == true).length} attending',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  isAttending
                                                      ? OutlinedButton.icon(
                                                          onPressed: () =>
                                                              _rsvp(
                                                                event['id'],
                                                                false,
                                                              ),
                                                          icon: const Icon(
                                                            Icons.check_circle,
                                                            color: Colors.green,
                                                            size: 18,
                                                          ),
                                                          label: const Text(
                                                            'Attending',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                          ),
                                                          style: OutlinedButton.styleFrom(
                                                            side:
                                                                const BorderSide(
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                          ),
                                                        )
                                                      : ElevatedButton.icon(
                                                          onPressed: () =>
                                                              _rsvp(
                                                                event['id'],
                                                                true,
                                                              ),
                                                          icon: const Icon(
                                                            Icons
                                                                .event_available,
                                                            size: 18,
                                                          ),
                                                          label: const Text(
                                                            'RSVP',
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                        ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
