import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/relation.dart';

class RelationService {
  final FirebaseFirestore _db;

  RelationService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _relationsCollection =>
      _db.collection('relations');

  /// Fetches a specific relation using the deterministic composite document ID: `${viewerId}_${authorId}`
  Future<ViewerAuthorRelation?> getRelation(
    String viewerId,
    String authorId,
  ) async {
    final String docId = '${viewerId}_$authorId';
    final doc = await _relationsCollection.doc(docId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return ViewerAuthorRelation.fromMap(doc.data()!);
  }

  /// REQ-FUNC-007 (Interruption handling)
  /// Marks a specific card presentation flow as "Pending".
  /// If a relationship is already recorded with `discovery_consumed = true`, the operation is ignored.
  Future<void> markCardAsPending({
    required String viewerId,
    required String authorId,
  }) async {
    final String docId = '${viewerId}_$authorId';
    final DocumentReference<Map<String, dynamic>> ref = _relationsCollection
        .doc(docId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final bool alreadyConsumed =
            data['discovery_consumed'] as bool? ?? false;
        // Strict guard gate: Once marked consumed, it cannot retroactively be made pending again.
        if (alreadyConsumed) return;
      }

      // Write or update the relation block
      transaction.set(ref, {
        'viewerId': viewerId,
        'authorId': authorId,
        'discovery_consumed': false,
        'pending_card': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// REQ-FUNC-005, REQ-FUNC-011 (Enforcing final consuming action)
  /// Validates state, resolves any active "pending_card" status, commits the chosen outcome
  /// (subscribe, read_later, next) atomically, and records an transaction audit entry.
  Future<void> resolvePendingCard({
    required String viewerId,
    required String authorId,
    required ActionType action,
  }) async {
    assert(
      action != ActionType.none,
      "Cannot resolve pending card with a state of ActionType.none",
    );

    final String docId = '${viewerId}_$authorId';
    final DocumentReference<Map<String, dynamic>> relationRef =
        _relationsCollection.doc(docId);
    final DocumentReference<Map<String, dynamic>> logRef = _db
        .collection('action_logs')
        .doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(relationRef);
      bool isCurrentlySubscribed = false;
      bool isCurrentlyReadLater = false;

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final bool alreadyConsumed =
            data['discovery_consumed'] as bool? ?? false;
        // Security gate guard checking if client is attempting to change an already completed gate
        if (alreadyConsumed) {
          throw StateError(
            'This discovery interaction was already finalized and closed.',
          );
        }
        isCurrentlySubscribed = data['subscribed'] as bool? ?? false;
        isCurrentlyReadLater = data['read_later'] as bool? ?? false;
      }

      final Map<String, dynamic> updateData = {
        'viewerId': viewerId,
        'authorId': authorId,
        'pending_card': false,
        'discovery_consumed': true,
        'action_type': action.toValueString(),
        'subscribed': action == ActionType.subscribe
            ? true
            : isCurrentlySubscribed,
        'read_later': action == ActionType.readLater
            ? true
            : isCurrentlyReadLater,
        'consumed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Set options to merge in case properties like `liked` were already written
      transaction.set(relationRef, updateData, SetOptions(merge: true));

      // Append transaction audit trail (REQ-OBS-001)
      transaction.set(logRef, {
        'viewerId': viewerId,
        'authorId': authorId,
        'action': action.toValueString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Interruption Handler Recovery (REQ-FUNC-007)
  /// Checks if there is a pending card session that needs completion.
  /// Standard Firestore allows filtering on simple criteria (where viewer matches, where pending_card is true).
  Future<ViewerAuthorRelation?> findInterruptedPendingCard(
    String viewerId,
  ) async {
    final query = await _relationsCollection
        .where('viewerId', isEqualTo: viewerId)
        .where('pending_card', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }
    return ViewerAuthorRelation.fromMap(query.docs.first.data());
  }

  /// Toggles the 'liked' boolean flag across discovery or ongoing content reads.
  Future<void> setLikedStatus({
    required String viewerId,
    required String authorId,
    required bool liked,
  }) async {
    final String docId = '${viewerId}_$authorId';
    await _relationsCollection.doc(docId).set({
      'liked': liked,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// REQ-FUNC-011: records that a viewer visited an author's profile, purely
  /// for history purposes. This must NEVER touch discovery_consumed —
  /// browsing a profile is an ancillary action, not a consuming one.
  Future<void> recordProfileVisit({
    required String viewerId,
    required String authorId,
  }) async {
    final String docId = '${viewerId}_$authorId';
    await _relationsCollection.doc(docId).set({
      'viewerId': viewerId,
      'authorId': authorId,
      'profile_visited_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// REQ-FUNC-012: a viewer may subscribe/unsubscribe at any time (e.g. from
  /// a profile reached via Search or the Viewed/Liked feeds), independent of
  /// the discovery mechanic. This intentionally does NOT touch
  /// discovery_consumed — that field is only ever set by resolvePendingCard.
  /// Unsubscribing does not restore a previously consumed discovery chance.
  Future<void> setSubscribedStatus({
    required String viewerId,
    required String authorId,
    required bool subscribed,
  }) async {
    final String docId = '${viewerId}_$authorId';
    await _relationsCollection.doc(docId).set({
      'viewerId': viewerId,
      'authorId': authorId,
      'subscribed': subscribed,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Updates the read later shelf presence for a specific author card.
  Future<void> setReadLaterStatus({
    required String viewerId,
    required String authorId,
    required bool readLater,
  }) async {
    final String docId = '${viewerId}_$authorId';
    await _relationsCollection.doc(docId).set({
      'viewerId': viewerId,
      'authorId': authorId,
      'read_later': readLater,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Streams relationship changes dynamically for state-rebuilding reactive contexts.
  Stream<ViewerAuthorRelation?> streamRelation(
    String viewerId,
    String authorId,
  ) {
    final String docId = '${viewerId}_$authorId';
    return _relationsCollection.doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return ViewerAuthorRelation.fromMap(snapshot.data()!);
    });
  }
}
