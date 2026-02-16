import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/database_helper.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = true; // Start as loading to check session

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  bool get isUsingDefaultPassword {
    if (_currentUser == null) return false;
    // Check if password matches hashed 'admin' or plain 'admin' (legacy)
    final hashedAdmin = DatabaseHelper.instance.hashPassword('admin');
    return _currentUser!.password == 'admin' ||
        _currentUser!.password == hashedAdmin;
  }

  AuthProvider() {
    tryAutoLogin();
  }

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('userId')) {
      final userId = prefs.getInt('userId');
      if (userId != null) {
        final user = await DatabaseHelper.instance.getUserById(userId);
        if (user != null) {
          _currentUser = user;
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    final user = await DatabaseHelper.instance.login(username, password);

    if (user != null) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', user.id!);
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    notifyListeners();
  }

  Future<bool> updatePassword(String newPassword) async {
    if (_currentUser == null || _currentUser!.id == null) return false;

    final result = await DatabaseHelper.instance.updateUserPassword(
      _currentUser!.id!,
      newPassword,
    );
    if (result > 0) {
      // Refresh user from DB to get the new hashed password in our model
      _currentUser = await DatabaseHelper.instance.getUserById(
        _currentUser!.id!,
      );
      notifyListeners();
      return true;
    }
    return false;
  }
}
