import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  bool _loading = false;
  String? _error;

  AuthUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.login(email, password);
    } on DioException catch (e) {
      _error = _parseError(e);
    } catch (_) {
      _error = 'Error inesperado. Intenta de nuevo.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        return (errors.values.first as List).first.toString();
      }
      if (data['message'] != null) return data['message'].toString();
    }
    return 'Error de conexión. Verifica tu red.';
  }
}
