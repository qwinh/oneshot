import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prime_content.dart';

class DiscoveryService {
  final FirebaseFirestore _db;

  DiscoveryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// REQ-FUNC-006: Tag browse filtered by discovery state.
  /// Returns authors tagged with [tag] whose discovery chance is not yet
  /// consumed by [viewerId]. Excludes hidden profiles.
  Future<List<AuthorProfile>> browseByTag({
    required String viewerId,
    required String tag,
    int limit = 20,
  }) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 1. Get all authors under this tag
    final tagSnap = await _db
        .collection('tags')
        .doc(normalizedTag)
        .collection('authors')
        .limit(limit)
        .get();

    if (tagSnap.docs.isEmpty) return [];

    final List<String> authorIds = tagSnap.docs
        .map((d) => d.data()['authorId'] as String)
        .toList();

    // 2. Fetch consumed relation IDs for this viewer in one query
    // Firestore whereIn limit is 30
    final relSnap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('authorId', whereIn: authorIds)
        .where('discovery_consumed', isEqualTo: true)
        .get();

    final Set<String> consumedAuthorIds = relSnap.docs
        .map((d) => d.data()['authorId'] as String)
        .toSet();

    // 3. Filter out consumed and self
    final List<String> eligibleIds = authorIds
        .where((id) => !consumedAuthorIds.contains(id) && id != viewerId)
        .toList();

    if (eligibleIds.isEmpty) return [];

    // 4. Fetch full author profiles
    final List<AuthorProfile> profiles = [];
    for (final id in eligibleIds) {
      final doc = await _db.collection('authors').doc(id).get();
      if (!doc.exists || doc.data() == null) continue;
      final profile = AuthorProfile.fromMap(id, doc.data()!);
      if (!profile.hidden) profiles.add(profile);
    }

    return profiles;
  }

  /// REQ-FUNC-007: Check for an interrupted pending card.
  /// Returns the authorId of a pending card if one exists.
  Future<String?> findPendingCardAuthorId(String viewerId) async {
    final snap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('pending_card', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['authorId'] as String?;
  }

  /// Fetch a single author profile by ID.
  Future<AuthorProfile?> getAuthorProfile(String authorId) async {
    final doc = await _db.collection('authors').doc(authorId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AuthorProfile.fromMap(authorId, doc.data()!);
  }
}
