// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _deptController = TextEditingController();
  final _yearController = TextEditingController();

  String _selectedRole = 'ALUMNI';
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // File upload states
  Uint8List? _idCardBytes;
  String? _idCardFilename;
  Uint8List? _profilePicBytes;
  String? _profilePicFilename;

  // Real-time availability state
  bool? _usernameAvailable;
  bool? _emailAvailable;
  bool _checkingUsername = false;
  bool _checkingEmail = false;

  // Backend error messages
  String? _serverError;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _regNoController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  bool get _needsIdCard =>
      _selectedRole == 'ALUMNI' || _selectedRole == 'STUDENT';

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }
    setState(() => _checkingUsername = true);
    final result = await _apiService.checkAvailability(username: username);
    if (mounted) {
      setState(() {
        _usernameAvailable = result['username_taken'] == true ? false : true;
        _checkingUsername = false;
      });
    }
  }

  Future<void> _checkEmailAvailability(String email) async {
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _emailAvailable = null;
        _checkingEmail = false;
      });
      return;
    }
    setState(() => _checkingEmail = true);
    final result = await _apiService.checkAvailability(email: email);
    if (mounted) {
      setState(() {
        _emailAvailable = result['email_taken'] == true ? false : true;
        _checkingEmail = false;
      });
    }
  }

  /// Web-native file picker using dart:html — no plugin required.
  void _pickIdCard() {
    final input = html.FileUploadInputElement()
      ..accept = '.jpg,.jpeg,.png,.pdf'
      ..click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoad.listen((_) {
        final bytes = reader.result as Uint8List;
        setState(() {
          _idCardBytes = bytes;
          _idCardFilename = file.name;
        });
      });
    });
  }

  void _pickProfilePicture() {
    final input = html.FileUploadInputElement()
      ..accept = '.jpg,.jpeg,.png'
      ..click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoad.listen((_) {
        final bytes = reader.result as Uint8List;
        setState(() {
          _profilePicBytes = bytes;
          _profilePicFilename = file.name;
        });
      });
    });
  }

  Future<void> _register() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    if (_profilePicBytes == null) {
      setState(
        () => _serverError =
            'Please upload a Profile Picture before registering.',
      );
      return;
    }

    if (_needsIdCard && _idCardBytes == null) {
      setState(
        () => _serverError = 'Please upload your ID card before registering.',
      );
      return;
    }
    if (_usernameAvailable == false) {
      setState(() => _serverError = 'Please choose a different username.');
      return;
    }
    if (_emailAvailable == false) {
      setState(
        () => _serverError = 'An account with this email already exists.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.registerWithFile(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      role: _selectedRole,
      idCardBytes: _idCardBytes != null ? List<int>.from(_idCardBytes!) : null,
      idCardFilename: _idCardFilename,
      profilePictureBytes: _profilePicBytes != null
          ? List<int>.from(_profilePicBytes!)
          : null,
      profilePictureFilename: _profilePicFilename,
      regNo: _needsIdCard ? _regNoController.text.trim() : null,
      department: _needsIdCard ? _deptController.text.trim() : null,
      graduationYear: _needsIdCard ? _yearController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration submitted! Your account is pending approval.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
      context.go('/login');
    } else {
      final errors = result['data'] as Map?;
      if (errors != null) {
        final msgs = <String>[];
        errors.forEach((key, value) {
          if (value is List)
            msgs.add('${_fieldLabel(key)}: ${value.join(' ')}');
          else
            msgs.add('${_fieldLabel(key)}: $value');
        });
        setState(() => _serverError = msgs.join('\n'));
      } else {
        setState(() => _serverError = 'Registration failed. Please try again.');
      }
    }
  }

  String _fieldLabel(String key) {
    const labels = {
      'username': 'Username',
      'email': 'Email',
      'password': 'Password',
      'id_card': 'ID Card',
    };
    return labels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Create an Account',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Join the Alumni Network',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role selector (drives ID card visibility)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Registering as *',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ALUMNI',
                            child: Text('Alumni'),
                          ),
                          DropdownMenuItem(
                            value: 'STUDENT',
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: 'FACULTY',
                            child: Text('Faculty'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Name row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: InputDecoration(
                                labelText: 'First Name *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: InputDecoration(
                                labelText: 'Last Name *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_needsIdCard) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _regNoController,
                                decoration: InputDecoration(
                                  labelText: 'Registration No *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _deptController,
                                decoration: InputDecoration(
                                  labelText: 'Department *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _yearController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Passout Year *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return 'Required';
                                  if (int.tryParse(v) == null || v.length != 4)
                                    return 'Valid Year';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: _checkingUsername
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _usernameAvailable == null
                              ? null
                              : Icon(
                                  _usernameAvailable!
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _usernameAvailable!
                                      ? Colors.green
                                      : Colors.red,
                                ),
                          helperText: _usernameAvailable == null
                              ? 'At least 3 characters'
                              : _usernameAvailable!
                              ? '✓ Username is available'
                              : '✗ Username is already taken',
                          helperStyle: TextStyle(
                            color: _usernameAvailable == null
                                ? Colors.grey
                                : _usernameAvailable!
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        onChanged: (v) {
                          setState(() => _usernameAvailable = null);
                          Future.delayed(const Duration(milliseconds: 600), () {
                            if (_usernameController.text == v)
                              _checkUsernameAvailability(v.trim());
                          });
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Username is required';
                          if (v.trim().length < 3)
                            return 'Username must be at least 3 characters';
                          if (_usernameAvailable == false)
                            return 'This username is already taken';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: _checkingEmail
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _emailAvailable == null
                              ? null
                              : Icon(
                                  _emailAvailable!
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _emailAvailable!
                                      ? Colors.green
                                      : Colors.red,
                                ),
                          helperText: _emailAvailable == null
                              ? null
                              : _emailAvailable!
                              ? '✓ Email is available'
                              : '✗ An account with this email already exists',
                          helperStyle: TextStyle(
                            color: _emailAvailable == null
                                ? Colors.grey
                                : _emailAvailable!
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        onChanged: (v) {
                          setState(() => _emailAvailable = null);
                          Future.delayed(const Duration(milliseconds: 700), () {
                            if (_emailController.text == v)
                              _checkEmailAvailability(v.trim());
                          });
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Email is required';
                          if (!v.contains('@') || !v.contains('.'))
                            return 'Enter a valid email address';
                          if (_emailAvailable == false)
                            return 'An account with this email already exists';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          helperText: 'Minimum 8 characters',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Password is required';
                          if (v.length < 8)
                            return 'Password must be at least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ID card upload — Alumni & Student only
                      if (_needsIdCard) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.badge,
                              size: 18,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ID Card Upload  (Required)',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'As ${_selectedRole == 'ALUMNI' ? 'an Alumni' : 'a Student'}, upload your official ID card (JPG, PNG, or PDF) for identity verification.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickIdCard,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _idCardBytes != null
                                    ? Colors.green
                                    : theme.colorScheme.primary.withOpacity(
                                        0.5,
                                      ),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: _idCardBytes != null
                                  ? Colors.green.shade50
                                  : theme.colorScheme.primary.withOpacity(0.04),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _idCardBytes != null
                                      ? Icons.check_circle
                                      : Icons.upload_file,
                                  color: _idCardBytes != null
                                      ? Colors.green
                                      : theme.colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _idCardBytes != null
                                            ? 'ID Card Selected'
                                            : 'Click to upload ID card',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _idCardBytes != null
                                              ? Colors.green.shade700
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        _idCardFilename ??
                                            'JPG, PNG, or PDF accepted',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_idCardBytes != null)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _idCardBytes = null;
                                      _idCardFilename = null;
                                    }),
                                    child: const Text(
                                      'Change',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Profile Picture Upload (Required for ALL user types)
                      Row(
                        children: [
                          const Icon(
                            Icons.account_circle,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Profile Picture (Required)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload a clear photo for your profile.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickProfilePicture,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _profilePicBytes != null
                                  ? Colors.green
                                  : theme.colorScheme.primary.withOpacity(0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: _profilePicBytes != null
                                ? Colors.green.shade50
                                : theme.colorScheme.primary.withOpacity(0.04),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _profilePicBytes != null
                                    ? Icons.check_circle
                                    : Icons.add_a_photo,
                                color: _profilePicBytes != null
                                    ? Colors.green
                                    : theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profilePicBytes != null
                                          ? 'Profile Picture Selected'
                                          : 'Click to upload picture',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _profilePicBytes != null
                                            ? Colors.green.shade700
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      _profilePicFilename ??
                                          'JPG or PNG accepted',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_profilePicBytes != null)
                                TextButton(
                                  onPressed: () => setState(() {
                                    _profilePicBytes = null;
                                    _profilePicFilename = null;
                                  }),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Server error box
                      if (_serverError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _serverError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Already have an account? Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
