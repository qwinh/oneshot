import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream to monitor auth status reactively across the app context
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Retrieve the current logged-in Firebase User representation
  User? get currentUser => _auth.currentUser;

  /// Standard user login
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Create a new account, initialize standard User schema, and send verification email
  Future<UserCredential> register({
    required String email,
    required String password,
    String? ipAddress,
  }) async {
    final UserCredential credential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password);

    final User? user = credential.user;
    if (user != null) {
      // Send the initial verification email automatically
      await user.sendEmailVerification();

      // Write user profile matching the Schema structure (email, isVerified placeholder, ip_address, created_at)
      await _db.collection('users').doc(user.uid).set({
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'ip_address': ipAddress ?? '0.0.0.0', // Recorded at registration
      });
    }

    return credential;
  }

  /// Resends verification email to the logged in user
  Future<void> sendVerificationEmail() async {
    final User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Forces refreshing of user properties from Firebase servers
  /// Required to detect when the user verifies their email via link clicks.
  Future<User?> refreshUserStatus() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser;
    }
    return null;
  }

  /// Performs logout operations
  Future<void> logout() async {
    await _auth.signOut();
  }
}
