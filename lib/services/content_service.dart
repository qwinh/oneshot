import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prime_content.dart';

class ContentService {
  final FirebaseFirestore _db;

  ContentService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  String _normalizeHandle(String handle) => handle.toLowerCase().trim();

  /// Fetches an author profile by UID
  Future<AuthorProfile?> getProfile(String uid) async {
    final doc = await _db.collection('authors').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return AuthorProfile.fromMap(uid, doc.data()!);
  }

  Future<bool> isHandleTaken(String handle, {String? excludingUid}) async {
    final String normalizedHandle = _normalizeHandle(handle);
    if (normalizedHandle.isEmpty) return false;

    final handleSnap = await _db
        .collection('handles')
        .doc(normalizedHandle)
        .get();
    if (!handleSnap.exists || handleSnap.data() == null) {
      return false;
    }

    final data = handleSnap.data()!;
    final claimedBy = data['uid'] as String? ?? '';
    return claimedBy.isNotEmpty && claimedBy != excludingUid;
  }

  /// Creates or updates the AuthorProfile document in the database.
  /// This operation updates `authors/{uid}` and populates the inverted tag lookup index (`tags/{tag}/authors/{uid}`).
  ///
  /// It also keeps the parent `tags/{tag}` document itself in sync, via an
  /// `authorCount` field:
  ///   - the parent doc is created the moment a tag gains its first author
  ///   - the parent doc's count is incremented/decremented as authors are
  ///     added to / removed from the tag
  ///   - the parent doc is deleted once a tag has zero authors left
  ///
  /// This is what makes `getAllActiveTags()` (which only reads the `tags`
  /// collection itself, not the subcollections) actually reflect reality.
  ///
  /// Crucially, updating the profile DOES NOT modify or reset any active
  /// viewer relationships.
  Future<void> saveAuthorProfile(AuthorProfile profile) async {
    final DocumentReference authorRef = _db
        .collection('authors')
        .doc(profile.uid);
    final String normalizedHandle = _normalizeHandle(profile.handle);
    final DocumentReference handleRef = _db
        .collection('handles')
        .doc(normalizedHandle);

    // Run transaction to write AuthorProfile & align inverted tag lookup safely
    await _db.runTransaction((transaction) async {
      // 1. Fetch current profile version to compare tag changes
      final authorSnap = await transaction.get(authorRef);
      List<String> originalTags = [];
      String? originalHandle;

      if (authorSnap.exists && authorSnap.data() != null) {
        final data = authorSnap.data() as Map<String, dynamic>;
        originalTags = List<String>.from(data['tags'] ?? []);
        originalHandle = _normalizeHandle(data['handle'] as String? ?? '');
      }

      if (originalHandle != null &&
          originalHandle.isNotEmpty &&
          originalHandle != normalizedHandle) {
        throw StateError('Handle is permanent and cannot be changed.');
      }

      final handleSnap = await transaction.get(handleRef);
      if (handleSnap.exists && handleSnap.data() != null) {
        final data = handleSnap.data() as Map<String, dynamic>;
        final claimedBy = data['uid'] as String? ?? '';
        if (claimedBy.isNotEmpty && claimedBy != profile.uid) {
          throw StateError('That handle is already taken.');
        }
      }

      final List<String> normalizedNewTags = profile.tags
          .map((t) => t.toLowerCase().trim())
          .toList();

      final List<String> removedTags = originalTags
          .where((t) => !normalizedNewTags.contains(t))
          .toList();
      final List<String> addedTags = normalizedNewTags
          .where((t) => !originalTags.contains(t))
          .toList();

      // --- ALL READS MUST HAPPEN BEFORE ANY WRITES IN A TRANSACTION ---
      final Map<String, DocumentSnapshot> tagDocSnaps = {};
      for (final tag in {...removedTags, ...addedTags}) {
        tagDocSnaps[tag] = await transaction.get(
          _db.collection('tags').doc(tag),
        );
      }

      // --- WRITES FROM HERE ON ---

      // 2. Map current changes
      transaction.set(authorRef, profile.toMap(), SetOptions(merge: true));
      transaction.set(handleRef, {
        'uid': profile.uid,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Remove this author reference from any tags that were deleted,
      // decrement that tag's authorCount, and prune the parent tag
      // document entirely once its count hits zero.
      for (final oldTag in removedTags) {
        final DocumentReference tagDocRef = _db.collection('tags').doc(oldTag);
        final DocumentReference tagAuthorRef = tagDocRef
            .collection('authors')
            .doc(profile.uid);
        transaction.delete(tagAuthorRef);

        final snap = tagDocSnaps[oldTag]!;
        final currentCount =
            (snap.data() as Map<String, dynamic>?)?['authorCount'] as int? ?? 1;
        final newCount = currentCount - 1;

        if (newCount <= 0) {
          transaction.delete(tagDocRef);
        } else {
          transaction.set(tagDocRef, {
            'authorCount': newCount,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // 4. Insert or update this author reference into new tag index nodes.
      // Only increment authorCount for tags that are genuinely new to this
      // author (re-saving an unchanged tag must not inflate the count).
      for (final newTag in normalizedNewTags) {
        final DocumentReference tagDocRef = _db.collection('tags').doc(newTag);
        final DocumentReference tagAuthorRef = tagDocRef
            .collection('authors')
            .doc(profile.uid);

        transaction.set(tagAuthorRef, {
          'authorId': profile.uid,
          'handle': profile.handle,
          'displayName': profile.displayName,
          'prime_content_type': profile.contentTypeString,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (addedTags.contains(newTag)) {
          final snap = tagDocSnaps[newTag]!;
          final currentCount = snap.exists
              ? ((snap.data() as Map<String, dynamic>?)?['authorCount']
                        as int? ??
                    0)
              : 0;
          transaction.set(tagDocRef, {
            'tag': newTag,
            'authorCount': currentCount + 1,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    });
  }
}
