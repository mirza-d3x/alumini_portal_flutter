import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Read the API URL from build arguments, fallback to localhost for development.
  // When building for deployment, run:
  // flutter build web --dart-define=API_URL=https://alumni-backend-9qt9.onrender.com/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://alumni-backend-9qt9.onrender.com/api',
  );

  // ─── Logging helper ─────────────────────────────────────────────────────────
  void _log(
    String method,
    Uri url, {
    String? requestBody,
    int? statusCode,
    String? responseBody,
  }) {
    if (!kDebugMode) return;
    final sep = '─' * 60;
    debugPrint('\n$sep');
    debugPrint('📤 [$method] ${url.toString()}');
    if (requestBody != null && requestBody.isNotEmpty) {
      debugPrint(
        '   Body: ${requestBody.length > 500 ? '${requestBody.substring(0, 500)}…' : requestBody}',
      );
    }
    if (statusCode != null) {
      final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
      debugPrint('$emoji Response [$statusCode]');
      if (responseBody != null && responseBody.isNotEmpty) {
        debugPrint(
          '   Body: ${responseBody.length > 800 ? '${responseBody.substring(0, 800)}…' : responseBody}',
        );
      }
    }
    debugPrint(sep);
  }

  // ─── Auth headers ────────────────────────────────────────────────────────────
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── HTTP wrapper methods ─────────────────────────────────────────────────────
  Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
    bool isRetry = false,
  }) async {
    _log('GET', uri);
    try {
      final res = await http.get(uri, headers: headers ?? await _getHeaders());
      if (res.statusCode == 401 && !isRetry) {
        if (await _refreshToken()) {
          return _get(uri, headers: headers, isRetry: true);
        }
      }
      _log('GET', uri, statusCode: res.statusCode, responseBody: res.body);
      return res;
    } catch (e) {
      _log('GET ERROR', uri, responseBody: e.toString());
      return http.Response('{"error": "Connection failed"}', 500);
    }
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    bool isRetry = false,
  }) async {
    _log('POST', uri, requestBody: body);
    try {
      final res = await http.post(
        uri,
        headers: headers ?? await _getHeaders(),
        body: body,
      );
      if (res.statusCode == 401 && !isRetry) {
        if (await _refreshToken()) {
          return _post(uri, headers: headers, body: body, isRetry: true);
        }
      }
      _log('POST', uri, statusCode: res.statusCode, responseBody: res.body);
      return res;
    } catch (e) {
      _log('POST ERROR', uri, responseBody: e.toString());
      return http.Response('{"error": "Connection failed"}', 500);
    }
  }

  Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
    bool isRetry = false,
  }) async {
    _log('DELETE', uri);
    try {
      final res = await http.delete(
        uri,
        headers: headers ?? await _getHeaders(),
      );
      if (res.statusCode == 401 && !isRetry) {
        if (await _refreshToken()) {
          return _delete(uri, headers: headers, isRetry: true);
        }
      }
      _log('DELETE', uri, statusCode: res.statusCode, responseBody: res.body);
      return res;
    } catch (e) {
      _log('DELETE ERROR', uri, responseBody: e.toString());
      return http.Response('{"error": "Connection failed"}', 500);
    }
  }

  Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) return false;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await prefs.setString('access_token', data['access']);
        return true;
      }
    } catch (_) {}
    // If refresh fails, clear tokens (user needs to login again)
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    return false;
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────
  Future<String?> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/token/');
    final body = jsonEncode({'username': username, 'password': password});
    _log(
      'POST',
      uri,
      requestBody: '{"username":"$username","password":"[REDACTED]"}',
    );
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      _log(
        'POST',
        uri,
        statusCode: response.statusCode,
        responseBody: response.statusCode == 200
            ? '{"access":"[TOKEN]","refresh":"[TOKEN]"}'
            : response.body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        return null;
      } else if (response.statusCode >= 500) {
        return 'Internal Server Error (${response.statusCode}). Please refer to backend terminal logs.';
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        return 'Invalid username or password.';
      }
      return 'Login failed with status: ${response.statusCode}';
    } catch (e) {
      _log('POST ERROR', uri, responseBody: e.toString());
      return 'Network Error: Cannot connect to server.';
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    final res = await _post(
      Uri.parse('$baseUrl/auth/register/'),
      body: jsonEncode(userData),
    );
    return res.statusCode == 201;
  }

  /// Check if username or email is already taken. Returns field-level info.
  Future<Map<String, dynamic>> checkAvailability({
    String? username,
    String? email,
  }) async {
    final queryParams = <String, String>{};
    if (username != null && username.isNotEmpty)
      queryParams['username'] = username;
    if (email != null && email.isNotEmpty) queryParams['email'] = email;
    final uri = Uri.parse(
      '$baseUrl/users/check-availability/',
    ).replace(queryParameters: queryParams);
    try {
      final res = await _get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  /// Register using multipart form data so an ID card file can be attached.
  Future<Map<String, dynamic>> registerWithFile({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    List<int>? idCardBytes,
    String? idCardFilename,
    List<int>? profilePictureBytes,
    String? profilePictureFilename,
    String? regNo,
    String? department,
    String? graduationYear,
    String? currentCompany,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/register/'),
    );
    request.fields['username'] = username;
    request.fields['email'] = email;
    request.fields['phone_number'] = phoneNumber;
    request.fields['password'] = password;
    request.fields['first_name'] = firstName;
    request.fields['last_name'] = lastName;
    request.fields['role'] = role;
    if (regNo != null && regNo.isNotEmpty) request.fields['reg_no'] = regNo;
    if (department != null && department.isNotEmpty)
      request.fields['department'] = department;
    if (graduationYear != null && graduationYear.isNotEmpty)
      request.fields['graduation_year'] = graduationYear;
    if (currentCompany != null && currentCompany.isNotEmpty)
      request.fields['current_company'] = currentCompany;

    if (idCardBytes != null && idCardFilename != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'id_card',
          idCardBytes,
          filename: idCardFilename,
        ),
      );
    }
    if (profilePictureBytes != null && profilePictureFilename != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'profile_picture',
          profilePictureBytes,
          filename: profilePictureFilename,
        ),
      );
    }

    try {
      _log(
        'POST (multipart)',
        Uri.parse('$baseUrl/users/register/'),
        requestBody: 'fields: ${request.fields.keys.join(', ')}',
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _log(
        'POST (multipart)',
        Uri.parse('$baseUrl/users/register/'),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      final body = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'statusCode': response.statusCode,
        'data': body,
      };
    } catch (e) {
      return {
        'success': false,
        'data': {'error': 'Network error. Please try again.'},
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final userId = payload['user_id'];
      final response = await _get(Uri.parse('$baseUrl/users/$userId/'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      return null;
    }
    return null;
  }

  // --- Users ---
  Future<List<dynamic>> getProfiles() async {
    final res = await _get(Uri.parse('$baseUrl/profiles/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<List<dynamic>> getUsers() async {
    final res = await _get(Uri.parse('$baseUrl/users/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<String?> approveUser(int userId) async {
    final res = await _post(Uri.parse('$baseUrl/users/$userId/approve/'));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['status'] as String? ??
          'User verified/approved successfully.';
    }
    return null;
  }

  Future<bool> deleteUser(int userId) async {
    final res = await _delete(Uri.parse('$baseUrl/users/$userId/'));
    return res.statusCode == 204;
  }

  Future<bool> changeUserRole(int userId, String newRole) async {
    final res = await _post(
      Uri.parse('$baseUrl/users/$userId/change_role/'),
      body: jsonEncode({'role': newRole}),
    );
    return res.statusCode == 200;
  }

  Future<bool> blockUser(int userId) async {
    final res = await _post(Uri.parse('$baseUrl/users/$userId/block/'));
    return res.statusCode == 200;
  }

  Future<bool> unblockUser(int userId) async {
    final res = await _post(Uri.parse('$baseUrl/users/$userId/unblock/'));
    return res.statusCode == 200;
  }

  // --- Dashboard ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _get(Uri.parse('$baseUrl/dashboard-stats/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {
      'total_alumni': 0,
      'total_students': 0,
      'active_jobs': 0,
      'total_communities': 0,
      'total_events': 0,
      'total_notices': 0,
    };
  }

  Future<Map<String, dynamic>> getPendingRequests() async {
    final res = await _get(Uri.parse('$baseUrl/pending-requests/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'pending_users': [], 'pending_donations': []};
  }

  // --- Jobs ---
  Future<List<dynamic>> getJobs() async {
    final res = await _get(Uri.parse('$baseUrl/jobs/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> postJob(Map<String, dynamic> jobData) async {
    final res = await _post(
      Uri.parse('$baseUrl/jobs/'),
      body: jsonEncode(jobData),
    );
    return res.statusCode == 201;
  }

  Future<bool> deleteJob(int jobId) async {
    final res = await _delete(Uri.parse('$baseUrl/jobs/$jobId/'));
    return res.statusCode == 204;
  }

  Future<bool> createJob({
    required String title,
    required String companyName,
    String? location,
    required String jobType,
    required String description,
  }) async {
    final res = await _post(
      Uri.parse('$baseUrl/jobs/'),
      body: jsonEncode({
        'title': title,
        'company': companyName,
        if (location != null && location.isNotEmpty) 'location': location,
        'job_type': jobType,
        'description': description,
      }),
    );
    return res.statusCode == 201;
  }

  Future<List<dynamic>> getJobApplications() async {
    final res = await _get(Uri.parse('$baseUrl/job-applications/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> applyForJob({
    required int jobId,
    String? resumeLink,
    String? coverLetter,
  }) async {
    final res = await _post(
      Uri.parse('$baseUrl/job-applications/'),
      body: jsonEncode({
        'job': jobId,
        if (resumeLink != null && resumeLink.isNotEmpty)
          'resume_link': resumeLink,
        if (coverLetter != null && coverLetter.isNotEmpty)
          'cover_letter': coverLetter,
      }),
    );
    return res.statusCode == 201;
  }

  // --- Events ---
  Future<List<dynamic>> getEvents() async {
    final res = await _get(Uri.parse('$baseUrl/events/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> createEvent(Map<String, dynamic> data) async {
    final res = await _post(
      Uri.parse('$baseUrl/events/'),
      body: jsonEncode(data),
    );
    return res.statusCode == 201;
  }

  Future<bool> createEventWithImage({
    required String title,
    required String description,
    required String date,
    String? location,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/events/'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['date'] = date;
    if (location != null) request.fields['location'] = location;
    if (imageBytes != null && imageFilename != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'poster_image',
          imageBytes,
          filename: imageFilename,
        ),
      );
    }
    _log(
      'POST (multipart)',
      Uri.parse('$baseUrl/events/'),
      requestBody: 'title=$title',
    );
    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      _log(
        'POST (multipart)',
        Uri.parse('$baseUrl/events/'),
        statusCode: res.statusCode,
        responseBody: res.body,
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEvent(int eventId) async {
    final res = await _delete(Uri.parse('$baseUrl/events/$eventId/'));
    return res.statusCode == 204;
  }

  Future<bool> rsvpEvent(int eventId, bool attending) async {
    final res = await _post(
      Uri.parse('$baseUrl/rsvps/'),
      body: jsonEncode({'event': eventId, 'is_attending': attending}),
    );
    return res.statusCode == 201 || res.statusCode == 200;
  }

  // --- Posts / Notices ---
  Future<List<dynamic>> getPosts() async {
    final res = await _get(Uri.parse('$baseUrl/posts/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> createPost(Map<String, dynamic> data) async {
    final res = await _post(
      Uri.parse('$baseUrl/posts/'),
      body: jsonEncode(data),
    );
    return res.statusCode == 201;
  }

  Future<bool> createPostWithImage({
    required String content,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts/'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['content'] = content;
    if (imageBytes != null && imageFilename != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'poster_image',
          imageBytes,
          filename: imageFilename,
        ),
      );
    }
    _log(
      'POST (multipart)',
      Uri.parse('$baseUrl/posts/'),
      requestBody: 'content, poster_image',
    );
    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      _log(
        'POST (multipart)',
        Uri.parse('$baseUrl/posts/'),
        statusCode: res.statusCode,
        responseBody: res.body,
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePost(int postId) async {
    final res = await _delete(Uri.parse('$baseUrl/posts/$postId/'));
    return res.statusCode == 204;
  }

  // --- Communities ---
  Future<List<dynamic>> getCommunities() async {
    final res = await _get(Uri.parse('$baseUrl/communities/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> createCommunity(Map<String, dynamic> data) async {
    final res = await _post(
      Uri.parse('$baseUrl/communities/'),
      body: jsonEncode(data),
    );
    return res.statusCode == 201;
  }

  Future<List<dynamic>> getCommunityMessages(int communityId) async {
    final res = await _get(
      Uri.parse('$baseUrl/communities/$communityId/messages/'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> sendCommunityMessage(int communityId, String content) async {
    final res = await _post(
      Uri.parse('$baseUrl/communities/$communityId/messages/'),
      body: jsonEncode({'content': content}),
    );
    return res.statusCode == 201;
  }

  Future<bool> joinCommunity(int communityId) async {
    final res = await _post(
      Uri.parse('$baseUrl/communities/$communityId/join/'),
    );
    return res.statusCode == 200;
  }

  // --- Donations ---
  Future<List<dynamic>> getDonations() async {
    final res = await _get(Uri.parse('$baseUrl/donations/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> makeDonation(Map<String, dynamic> donationData) async {
    final res = await _post(
      Uri.parse('$baseUrl/donations/'),
      body: jsonEncode(donationData),
    );
    return res.statusCode == 201;
  }

  Future<bool> approveDonation(int donationId) async {
    final res = await _post(
      Uri.parse('$baseUrl/donations/$donationId/approve/'),
    );
    return res.statusCode == 200;
  }

  // --- Fund Allocations ---
  Future<List<dynamic>> getFundAllocations() async {
    final res = await _get(Uri.parse('$baseUrl/fund-allocations/'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<bool> allocateFund(Map<String, dynamic> fundData) async {
    final res = await _post(
      Uri.parse('$baseUrl/fund-allocations/'),
      body: jsonEncode(fundData),
    );
    return res.statusCode == 201;
  }
}
