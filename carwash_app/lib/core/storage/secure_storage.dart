import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  /// Si Android restauró un valor cifrado con una llave de Keystore que ya no
  /// existe (típico tras desinstalar/reinstalar, por el auto-backup del
  /// sistema), la lectura truena con una excepción de descifrado en vez de
  /// devolver null. Sin este try/catch, ese error queda sin capturar dentro
  /// del interceptor de Dio y la app se queda cargando para siempre. Como el
  /// valor es ilegible de todas formas, se trata igual que "no hay sesión".
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('[SecureStorage] Token ilegible, se limpia: $e');
      await _storage.deleteAll();
      return null;
    }
  }

  static Future<void> deleteToken() =>
      _storage.delete(key: _tokenKey);
}
