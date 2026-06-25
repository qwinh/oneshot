import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prime_content.dart';

class ContentService {
  final FirebaseFirestore _db;

  ContentService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Fetches an author profile by UID
  Future<AuthorProfile?> getProfile(String uid) async {
    final doc = await _db.collection('authors').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return AuthorProfile.fromMap(uid, doc.data()!);
  }

  /// Creates or updates the AuthorProfile document in the database.
  /// This operation updates `authors/{uid}` and populates the inverted tag lookup index (`tags/{tag}/authors/{uid}`).
  /// Crucially, updating the profile DOES NOT modify or reset any active viewer relationships.
  Future<void> saveAuthorProfile(AuthorProfile profile) async {
    final DocumentReference authorRef = _db
        .collection('authors')
        .doc(profile.uid);

    // Run transaction to write AuthorProfile & align inverted tag lookup safely
    await _db.runTransaction((transaction) async {
      // 1. Fetch current profile version to compare tag changes
      final authorSnap = await transaction.get(authorRef);
      List<String> originalTags = [];

      if (authorSnap.exists && authorSnap.data() != null) {
        final data = authorSnap.data() as Map<String, dynamic>;
        originalTags = List<String>.from(data['tags'] ?? []);
      }

      // 2. Map current changes
      transaction.set(authorRef, profile.toMap(), SetOptions(merge: true));

      // 3. Remove this author reference from any tags that were deleted
      final List<String> normalizedNewTags = profile.tags
          .map((t) => t.toLowerCase().trim())
          .toList();
      for (final oldTag in originalTags) {
        if (!normalizedNewTags.contains(oldTag)) {
          final DocumentReference tagRef = _db
              .collection('tags')
              .doc(oldTag)
              .collection('authors')
              .doc(profile.uid);
          transaction.delete(tagRef);
        }
      }

      // 4. Insert or update this author reference into new tag index nodes
      for (final newTag in normalizedNewTags) {
        final DocumentReference tagRef = _db
            .collection('tags')
            .doc(newTag)
            .collection('authors')
            .doc(profile.uid);

        transaction.set(tagRef, {
          'authorId': profile.uid,
          'handle': profile.handle,
          'displayName': profile.displayName,
          'prime_content_type': profile.contentTypeString,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
