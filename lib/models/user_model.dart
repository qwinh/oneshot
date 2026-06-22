import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the `users/{uid}` Firestore document described in Appendix A.
///
/// Note: `password_hash` is intentionally absent here — Firebase
/// Authentication owns credential storage (REQ-SEC-001), so the app never
/// reads, writes, or holds a password hash itself.
class UserModel {
  final String uid;
  final String email;
  final String ipAddress;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.ipAddress = '0.0.0.0',
    this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      ipAddress: map['ip_address'] as String? ?? '0.0.0.0',
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  /// Payload for the initial registration write (REQ-FUNC-001).
  /// `created_at` is always set server-side on creation.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'ip_address': ipAddress,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
