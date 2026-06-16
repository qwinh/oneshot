import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prime_content.dart';
import '../models/relation.dart';
import '../models/work.dart';

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

  /// Retrieves all active tags for directory navigation.
  Future<List<String>> getAllActiveTags() async {
    final snap = await _db.collection('tags').get();
    return snap.docs.map((doc) => doc.id).toList();
  }

  /// REQ-FUNC-014: Subscribe Feed
  /// Resolves the unified timeline of post updates (works) published by authors
  /// where a subscription exists. Relies on local memory queries to respect RULE 2.
  Future<List<Work>> getSubscribeFeed(String viewerId) async {
    // 1. Get all active subscriptions
    final relationsSnap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('subscribed', isEqualTo: true)
        .get();

    if (relationsSnap.docs.isEmpty) return [];

    final List<String> subscribedAuthorIds = relationsSnap.docs
        .map((doc) => doc.data()['authorId'] as String)
        .toList();

    // 2. Fetch works published by these authors (limit 30 due to whereIn)
    final chunkedIds = subscribedAuthorIds.take(30).toList();
    if (chunkedIds.isEmpty) return [];

    final worksSnap = await _db
        .collection('works')
        .where('authorId', whereIn: chunkedIds)
        .get();

    final List<Work> works = worksSnap.docs
        .map((doc) => Work.fromMap(doc.id, doc.data()))
        .toList();

    // Sort in memory by newest post first
    works.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return works;
  }

  /// REQ-FUNC-015: Read Later Feed
  /// Resolves all Prime cards the user has selected to read or review later.
  Future<List<AuthorProfile>> getReadLaterFeed(String viewerId) async {
    final relationsSnap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('read_later', isEqualTo: true)
        .get();

    if (relationsSnap.docs.isEmpty) return [];

    final List<AuthorProfile> profiles = [];
    for (var doc in relationsSnap.docs) {
      final authorId = doc.data()['authorId'] as String;
      final profile = await getAuthorProfile(authorId);
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  /// REQ-FUNC-016: Viewed Authors History Feed
  Future<List<AuthorProfile>> getViewedAuthorsFeed(String viewerId) async {
    final relationsSnap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('discovery_consumed', isEqualTo: true)
        .get();

    if (relationsSnap.docs.isEmpty) return [];

    final List<AuthorProfile> profiles = [];
    for (var doc in relationsSnap.docs) {
      final authorId = doc.data()['authorId'] as String;
      final profile = await getAuthorProfile(authorId);
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  /// REQ-FUNC-017: Liked Authors Feed
  Future<List<AuthorProfile>> getLikedAuthorsFeed(String viewerId) async {
    final relationsSnap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('liked', isEqualTo: true)
        .get();

    if (relationsSnap.docs.isEmpty) return [];

    final List<AuthorProfile> profiles = [];
    for (var doc in relationsSnap.docs) {
      final authorId = doc.data()['authorId'] as String;
      final profile = await getAuthorProfile(authorId);
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  /// REQ-FUNC-018: Exact handle search and partial display name match.
  Future<List<AuthorProfile>> searchAuthors(String query) async {
    final cleanedQuery = query.trim().toLowerCase();
    if (cleanedQuery.isEmpty) return [];

    // Query match on exact handle
    final handleQuerySnap = await _db
        .collection('authors')
        .where('handle', isEqualTo: cleanedQuery)
        .get();

    final List<AuthorProfile> results = [];
    for (var doc in handleQuerySnap.docs) {
      results.add(AuthorProfile.fromMap(doc.id, doc.data()));
    }

    // Fallback: search by Display Name matching start prefix
    if (results.isEmpty) {
      final nameQuerySnap = await _db
          .collection('authors')
          .orderBy('displayName')
          .startAt([query])
          .endAt([query + '\uf8ff'])
          .limit(10)
          .get();

      for (var doc in nameQuerySnap.docs) {
        results.add(AuthorProfile.fromMap(doc.id, doc.data()));
      }
    }

    return results.where((p) => !p.hidden).toList();
  }

  /// Publishes a regular content Update (Work) to the system.
  Future<void> publishWork({
    required String authorId,
    required String authorName,
    required String authorHandle,
    required String content,
  }) async {
    await _db.collection('works').add({
      'authorId': authorId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'content': content,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
