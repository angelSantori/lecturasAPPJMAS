import 'dart:convert';
import 'dart:io';
import 'package:app_lecturas_jmas/configs/controllers/users_controller.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  //  Casa
  //final String apiURL = 'http://192.168.0.2:5000/api'; // Casa http
  final String apiURL = 'https://192.168.0.7:5001/api'; //  Casa https

  //  Trabajo
  //final String apiURL = 'http://192.168.137.1:5000/api'; //  Wifi servidor http
  //final String apiURL = 'https://192.168.137.1:5001/api'; //  Wifi servidor https

  //  Server
  //final String apiURL = 'http://154.12.243.37/api';

  Users? _currentUser;

  IOClient _createHttpClient() {
    final ioClient = HttpClient();
    // Solo para desarrollo - remover en producción
    ioClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          debugPrint('Accepting bad certificate for $host:$port');
          return true;
        };
    return IOClient(ioClient);
  }

  Future<bool> checkApiConnection() async {
    try {
      final IOClient client = _createHttpClient();
      final response = await client
          .get(
            Uri.parse('$apiURL/health'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<void> ensureInitialized() async {
    try {
      await SharedPreferences.getInstance();
    } catch (e) {
      WidgetsFlutterBinding.ensureInitialized();
      await SharedPreferences.getInstance();
    }
  }

  // Guardar datos del usuario al iniciar sesión
  Future<void> saveUserData(Users user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', json.encode(user.toMap()));
    _currentUser = user;
  }

  // Obtener datos del usuar
  Future<Users?> getUserData() async {
    if (_currentUser != null) return _currentUser;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('userData');
    if (userData != null) {
      _currentUser = Users.fromJson(userData);
      return _currentUser;
    }
    return null;
  }

  // Limpiar datos al cerrar sesión
  Future<void> clearAuthData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('userData');
    _currentUser = null;
  }

  // Verificar permisos
  Future<bool> hasPermission(String permission) async {
    final user = await getUserData();
    if (user?.role == null) return false;

    switch (permission) {
      case 'view':
        return user!.role!.canView ?? false;
      case 'add':
        return user!.role!.canAdd ?? false;
      case 'edit':
        return user!.role!.canEdit ?? false;
      case 'delete':
        return user!.role!.canDelete ?? false;
      case 'manage_users':
        return user!.role!.canManageUsers ?? false;
      case 'manage_roles':
        return user!.role!.canManageRoles ?? false;
      case 'evaluar':
        return user!.role!.canEvaluar ?? false;
      case 'canCContable':
        return user!.role!.canCContables ?? false;
      case 'manageJunta':
        return user!.role!.canManageJuntas ?? false;
      case 'manageContratista':
        return user!.role!.canManageContratistas ?? false;
      case 'manageProveedor':
        return user!.role!.canManageProveedores ?? false;
      case 'manageCalle':
        return user!.role!.canManageCalles ?? false;
      case 'manageColonia':
        return user!.role!.canManageColonias ?? false;
      case 'manageAlmacen':
        return user!.role!.canManageAlmacenes ?? false;
      default:
        return false;
    }
  }

  //Save token en almacenamiento local
  Future<void> saveToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', token);
  }

  //Obtener token del almacenamiento local
  Future<String?> getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  //Delete token logout
  Future<void> deleteToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
  }

  //Decodificar el token
  Future<Map<String, dynamic>?> decodeToken() async {
    final String? token = await getToken();
    if (token == null) return null;

    // Decodificar el payload del token
    final parts = token.split('.');
    if (parts.length != 3) return null;

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return jsonDecode(payload);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      //Veridicar token
      final decoded = await decodeToken();
      if (decoded == null) return false;

      final exp = decoded['exp'] as int?;
      if (exp == null) return false;

      final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expirationDate);
    } catch (e) {
      print('Error isLoggedIn | AuthService: $e');
      return false;
    }
  }
}
