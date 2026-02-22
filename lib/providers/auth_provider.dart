import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final _supabase = sb.Supabase.instance.client;
  User? _currentUser;
  bool _isLoading = true;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _supabase.auth.currentSession != null;

  AuthProvider() {
    _initialize();
  }

  void _initialize() {
    // Listen to Auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final sb.Session? session = data.session;

      if (session != null) {
        _currentUser = User(
          id: 0, // Mock ID for compatibility
          username: session.user.email ?? 'User',
          password: '', // No password stored locally for OAuth
          role: session.user.email?.contains('admin') == true
              ? 'admin'
              : 'employee',
        );
      } else {
        _currentUser = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.auth.signInWithOAuth(sb.OAuthProvider.google);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // Backwards compatibility for the existing login UI if needed
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
