import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? get currentUser => _authService.currentUser;
  String? get currentUserId => _authService.currentUser?.uid;
  bool get isLoggedIn => _authService.currentUser != null;
  bool get isEmailVerified => _authService.currentUser?.emailVerified ?? false;

  /// Raw Firebase auth stream — used by AuthGateRouter in main.dart.
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.login(
      email: email,
      password: password,
    );
    notifyListeners();
    return credential;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    String? ipAddress,
  }) async {
    final credential = await _authService.register(
      email: email,
      password: password,
      ipAddress: ipAddress,
    );
    notifyListeners();
    return credential;
  }

  Future<void> sendVerificationEmail() => _authService.sendVerificationEmail();

  Future<User?> refreshUserStatus() async {
    final user = await _authService.refreshUserStatus();
    notifyListeners();
    return user;
  }

  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }

  Future<void> deleteAccount({required String password}) async {
    await _authService.deleteAccount(password: password);
    notifyListeners();
  }
}
