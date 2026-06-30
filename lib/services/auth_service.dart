import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

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

      // Write user profile matching the Schema structure (email, ip_address, created_at)
      final UserModel newUser = UserModel(
        uid: user.uid,
        email: email,
        ipAddress: ipAddress ?? '0.0.0.0',
      );
      await _db.collection('users').doc(user.uid).set(newUser.toMap());
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

  /// Deletes the current user's account permanently.
  /// Removes the Firestore profile doc first, then the Firebase Auth user.
  /// May throw a FirebaseAuthException with code 'requires-recent-login'
  /// if the session is too old — caller should prompt re-authentication.
  Future<void> deleteAccount({required String password}) async {
    final User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No logged-in user to delete.',
      );
    }

    // Re-authenticate first so the delete call doesn't fail on an aged session.
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    await _db.collection('users').doc(user.uid).delete();
    await user.delete();
  }
}
