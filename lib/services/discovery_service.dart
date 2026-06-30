import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prime_content.dart';
import '../models/relation.dart';
import '../models/work.dart';

/// A single row of the Viewed Authors Feed (REQ-FUNC-016): the author's
/// profile paired with the action that closed out their discovery chance
/// and when it happened.
class ViewedAuthorResult {
  final AuthorProfile profile;
  final ActionType actionType;
  final DateTime? consumedAt;

  const ViewedAuthorResult({
    required this.profile,
    required this.actionType,
    this.consumedAt,
  });
}

class DiscoveryService {
  final FirebaseFirestore _db;

  DiscoveryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// The default Discovery feed: lazily surfaces existing authors' prime
  /// works directly, with no tag selection required up front. [tag] is now
  /// just an optional filter layered on top of that feed — when provided,
  /// this simply delegates to [browseByTag]; when omitted, it pulls
  /// straight from the `authors` collection.
  ///
  /// Applies the same eligibility rules either way: not yet consumed by
  /// [viewerId], not the viewer's own profile, and not hidden.
  Future<List<AuthorProfile>> browseDiscoverable({
    required String viewerId,
    String? tag,
    int limit = 20,
  }) async {
    final normalizedTag = tag?.toLowerCase().trim();
    if (normalizedTag != null && normalizedTag.isNotEmpty) {
      return browseByTag(viewerId: viewerId, tag: normalizedTag, limit: limit);
    }

    // 1. Pull a general batch of authors directly — no tag prefilter.
    final authorsSnap = await _db.collection('authors').limit(limit).get();
    if (authorsSnap.docs.isEmpty) return [];

    final List<String> candidateIds = authorsSnap.docs
        .map((d) => d.id)
        .where((id) => id != viewerId)
        .toList();
    if (candidateIds.isEmpty) return [];

    // 2. Fetch consumed relation IDs for this viewer, chunked to respect
    // Firestore's 30-item `whereIn` limit.
    final Set<String> consumedAuthorIds = {};
    for (var i = 0; i < candidateIds.length; i += 30) {
      final end = (i + 30 > candidateIds.length) ? candidateIds.length : i + 30;
      final chunk = candidateIds.sublist(i, end);
      final relSnap = await _db
          .collection('relations')
          .where('viewerId', isEqualTo: viewerId)
          .where('authorId', whereIn: chunk)
          .where('discovery_consumed', isEqualTo: true)
          .get();
      consumedAuthorIds.addAll(
        relSnap.docs.map((d) => d.data()['authorId'] as String),
      );
    }

    // 3. Build out eligible profiles: not self, not consumed, not hidden.
    final List<AuthorProfile> profiles = [];
    for (final doc in authorsSnap.docs) {
      if (doc.id == viewerId) continue;
      if (consumedAuthorIds.contains(doc.id)) continue;
      final profile = AuthorProfile.fromMap(doc.id, doc.data());
      if (!profile.hidden) profiles.add(profile);
    }

    return profiles;
  }

  /// REQ-FUNC-006: Tag filter on top of the general discovery feed.
  /// Returns authors tagged with [tag] whose discovery chance is not yet
  /// consumed by [viewerId]. Excludes hidden profiles. Called directly for
  /// a tag-only query, or via [browseDiscoverable] when a tag filter is
  /// layered on top of the default lazy feed.
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

  /// Multi-tag discovery filter. [matchAll] = true means AND (author must
  /// carry every tag in [tags]); false means OR (author must carry at
  /// least one). Falls back to [browseDiscoverable] when [tags] is empty,
  /// and to [browseByTag] when there's exactly one tag (cheaper, no
  /// union/intersection step needed).
  ///
  /// Implementation note: each tag is queried independently against its
  /// `tags/{tag}/authors` subcollection (there's no native Firestore way to
  /// query "has ALL of these tags" against this schema), then the
  /// per-tag result sets are combined in memory. Because each per-tag
  /// query is itself capped at [limit], an AND query's true intersection
  /// could in theory be larger than what's visible here if a very popular
  /// tag's full author list isn't entirely fetched — acceptable for a
  /// discovery feed, but worth knowing if results ever look sparse for
  /// power users combining a very common tag with a very rare one.
  Future<List<AuthorProfile>> browseByTags({
    required String viewerId,
    required List<String> tags,
    bool matchAll = false,
    int limit = 20,
  }) async {
    final List<String> normalizedTags = tags
        .map((t) => t.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedTags.isEmpty) {
      return browseDiscoverable(viewerId: viewerId, limit: limit);
    }

    if (normalizedTags.length == 1) {
      return browseByTag(
        viewerId: viewerId,
        tag: normalizedTags.first,
        limit: limit,
      );
    }

    // Fetch each tag's eligible candidates in parallel.
    final List<List<AuthorProfile>> perTagResults = await Future.wait(
      normalizedTags.map(
        (t) => browseByTag(viewerId: viewerId, tag: t, limit: limit),
      ),
    );

    if (matchAll) {
      // AND: intersect author ids across every tag's result set.
      Set<String>? commonIds;
      for (final results in perTagResults) {
        final ids = results.map((p) => p.uid).toSet();
        commonIds = commonIds == null ? ids : commonIds.intersection(ids);
      }
      commonIds ??= {};

      // Preserve the order of the first tag's results for stability.
      final List<AuthorProfile> ordered = perTagResults.first
          .where((p) => commonIds!.contains(p.uid))
          .toList();

      return ordered.take(limit).toList();
    } else {
      // OR: union of all result sets, deduped by author id, first-seen order.
      final Map<String, AuthorProfile> byId = {};
      for (final results in perTagResults) {
        for (final p in results) {
          byId.putIfAbsent(p.uid, () => p);
        }
      }
      return byId.values.take(limit).toList();
    }
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

  /// REQ-FUNC-016: Viewed Authors History Feed.
  /// Must surface action_type and consumed_at per creator, not just the bare
  /// profile, so the viewer can see *how* and *when* each chance was used.
  Future<List<ViewedAuthorResult>> getViewedAuthorsFeed(String viewerId) async {
    final relationsSnap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('discovery_consumed', isEqualTo: true)
        .get();

    if (relationsSnap.docs.isEmpty) return [];

    final List<ViewedAuthorResult> results = [];
    for (var doc in relationsSnap.docs) {
      final data = doc.data();
      final authorId = data['authorId'] as String;
      final profile = await getAuthorProfile(authorId);
      if (profile == null) continue;
      results.add(
        ViewedAuthorResult(
          profile: profile,
          actionType: ActionTypeExtension.fromString(
            data['action_type'] as String?,
          ),
          consumedAt: data['consumed_at'] != null
              ? (data['consumed_at'] as Timestamp).toDate()
              : null,
        ),
      );
    }

    // Most recently judged creators first.
    results.sort((a, b) {
      if (a.consumedAt == null) return 1;
      if (b.consumedAt == null) return -1;
      return b.consumedAt!.compareTo(a.consumedAt!);
    });
    return results;
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

  /// REQ-FUNC-021: Standard post feed for a single author's profile.
  /// Visible to subscribers (via Subscribe Feed) and to any viewer who
  /// visits the profile directly — this powers the latter case.
  Future<List<Work>> getAuthorWorks(String authorId) async {
    final worksSnap = await _db
        .collection('works')
        .where('authorId', isEqualTo: authorId)
        .get();

    final List<Work> works = worksSnap.docs
        .map((doc) => Work.fromMap(doc.id, doc.data()))
        .toList();

    works.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return works;
  }

  /// Returns a set of author IDs that the viewer has subscribed to.
  Future<Set<String>> getSubscribedAuthorIds(String viewerId) async {
    final snap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('subscribed', isEqualTo: true)
        .get();
    return snap.docs.map((doc) => doc.data()['authorId'] as String).toSet();
  }

  /// Returns full AuthorProfile objects for all authors the viewer is subscribed to.
  Future<List<AuthorProfile>> getSubscribedAuthors(String viewerId) async {
    final relationsSnap = await _db
        .collection('relations')
        .where('viewerId', isEqualTo: viewerId)
        .where('subscribed', isEqualTo: true)
        .get();

    if (relationsSnap.docs.isEmpty) return [];

    final List<String> authorIds = relationsSnap.docs
        .map((doc) => doc.data()['authorId'] as String)
        .toList();

    // Fetch profiles in chunks of 30 for Firestore `whereIn`
    List<AuthorProfile> profiles = [];
    for (var i = 0; i < authorIds.length; i += 30) {
      final chunk = authorIds.sublist(
        i,
        (i + 30 > authorIds.length) ? authorIds.length : i + 30,
      );
      final snap = await _db
          .collection('authors')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        profiles.add(AuthorProfile.fromMap(doc.id, doc.data()));
      }
    }
    return profiles;
  }

  /// Publishes a regular content Update (Work) to the system.
  Future<void> publishWork({
    required String authorId,
    required String authorName,
    required String authorHandle,
    required List<PrimeBlock> blocks,
  }) async {
    final now = DateTime.now();
    final work = Work(
      id: '', // Firestore will assign an ID
      authorId: authorId,
      authorName: authorName,
      authorHandle: authorHandle,
      blocks: blocks,
      content: '', // let toMap compute it from blocks
      createdAt: now,
    );
    await _db.collection('works').add(work.toMap());
  }
}
