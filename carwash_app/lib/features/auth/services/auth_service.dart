import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/auth_user.dart';

class AuthService {
  AuthService._();

  static Future<AuthUser> login(String email, String password) async {
    final response = await ApiClient.instance.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await SecureStorage.saveToken(response.data['token']);
    return AuthUser.fromJson(response.data);
  }

  static Future<void> logout() async {
    try {
      await ApiClient.instance.post('/auth/logout');
    } on DioException {
      // Si falla la red igual borramos el token local
    }
    await SecureStorage.deleteToken();
  }
}
