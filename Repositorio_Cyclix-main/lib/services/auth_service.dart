import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'https://api.cyclix.site/api/v1';
  static const String _userDataKey = 'user_data';
  static const String _authTokenKey = 'auth_token';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';
  static const String _hasLoggedInKey = 'has_logged_in';

  final _storage = const FlutterSecureStorage();

  Future<void> saveUser(Map<String, dynamic> userData, String password) async {
    final token = userData['token']?.toString();

    await _storage.write(key: _userDataKey, value: jsonEncode(userData));
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: _authTokenKey, value: token);
    }
    await _storage.write(
      key: _savedEmailKey,
      value: userData['email']?.toString(),
    );
    await _storage.write(key: _savedPasswordKey, value: password);
    await _storage.write(key: _hasLoggedInKey, value: 'true');
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final data = await _storage.read(key: _userDataKey);
    if (data != null) return jsonDecode(data) as Map<String, dynamic>;
    return null;
  }

  Future<String?> getSavedToken() async {
    final token = await _storage.read(key: _authTokenKey);
    if (token != null && token.isNotEmpty) return token;

    final userData = await getUserData();
    final userDataToken = userData?['token']?.toString();
    if (userDataToken != null && userDataToken.isNotEmpty) {
      await _storage.write(key: _authTokenKey, value: userDataToken);
      return userDataToken;
    }
    return null;
  }

  Future<bool> hasPreviousLogin() async {
    try {
      final token = await getSavedToken();
      final userData = await getUserData();
      return token != null && token.isNotEmpty && userData != null;
    } catch (e) {
      print('Error leyendo sesion guardada: $e');
      return false;
    }
  }

  Future<String?> getSavedEmail() async => _storage.read(key: _savedEmailKey);
  Future<String?> getSavedPassword() async =>
      _storage.read(key: _savedPasswordKey);

  Future<void> logout() async {
    await _storage.delete(key: _userDataKey);
    await _storage.delete(key: _authTokenKey);
    await _storage.delete(key: _savedEmailKey);
    await _storage.delete(key: _savedPasswordKey);
    await _storage.delete(key: _hasLoggedInKey);
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> loginData = jsonDecode(response.body);
        final String token = loginData['token'];

        // Intentamos obtener los detalles completos del usuario desde la lista de la API
        final userDetails = await _fetchUserDetails(email, token);

        // Combinamos el token con los detalles encontrados (o los básicos si fallara)
        final Map<String, dynamic> fullData = {
          'email': email,
          'token': token,
          ...?(userDetails as Map<String, dynamic>?),
        };

        await saveUser(fullData, password);
        return fullData;
      }
      return null;
    } catch (e) {
      print('Error de conexión: $e');
      return null;
    }
  }

  // Busca al usuario actual en la lista general de la API para obtener su nombre y teléfono
  Future<Map<String, dynamic>?> _fetchUserDetails(
    String email,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> users = jsonDecode(response.body);
        // Buscamos el usuario que coincida con el email que acaba de loguearse
        for (var user in users) {
          if (user is Map<String, dynamic> && user['email'] == email) {
            return user;
          }
        }
      }
    } catch (e) {
      print('Error al obtener detalles del usuario: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
