import 'package:flutter/foundation.dart';
import '../models/relation.dart';
import '../services/relation_service.dart';

/// Caches ViewerAuthorRelation objects keyed by authorId.
/// Screens read from this cache instead of calling RelationService directly,
/// so any mutation (subscribe, like, read-later) immediately reflects
/// everywhere the relation is displayed.
class RelationProvider extends ChangeNotifier {
  final RelationService _service = RelationService();

  // authorId -> relation
  final Map<String, ViewerAuthorRelation?> _cache = {};

  // authorId -> in-flight update flag (prevents double-taps)
  final Set<String> _updating = {};

  // ── Read ──────────────────────────────────────────────────────────────────

  ViewerAuthorRelation? getRelation(String authorId) => _cache[authorId];

  bool isUpdating(String authorId) => _updating.contains(authorId);

  bool isSubscribed(String authorId) => _cache[authorId]?.subscribed ?? false;

  bool isLiked(String authorId) => _cache[authorId]?.liked ?? false;

  bool isReadLater(String authorId) => _cache[authorId]?.readLater ?? false;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Fetches and caches the relation for [viewerId] ↔ [authorId].
  /// No-ops if the relation is already in cache; use [refresh] to force.
  Future<void> load(String viewerId, String authorId) async {
    if (_cache.containsKey(authorId)) return;
    await _fetch(viewerId, authorId);
  }

  /// Always re-fetches from Firestore, replacing the cached value.
  Future<void> refresh(String viewerId, String authorId) =>
      _fetch(viewerId, authorId);

  Future<void> _fetch(String viewerId, String authorId) async {
    final relation = await _service.getRelation(viewerId, authorId);
    _cache[authorId] = relation;
    notifyListeners();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> setSubscribed({
    required String viewerId,
    required String authorId,
    required bool subscribed,
  }) async {
    if (_updating.contains(authorId)) return;
    _updating.add(authorId);
    notifyListeners();
    try {
      await _service.setSubscribedStatus(
        viewerId: viewerId,
        authorId: authorId,
        subscribed: subscribed,
      );
      // Optimistic update so the UI flips instantly.
      _patch(authorId, subscribed: subscribed);
    } finally {
      _updating.remove(authorId);
      notifyListeners();
    }
  }

  Future<void> setLiked({
    required String viewerId,
    required String authorId,
    required bool liked,
  }) async {
    if (_updating.contains(authorId)) return;
    _updating.add(authorId);
    notifyListeners();
    try {
      await _service.setLikedStatus(
        viewerId: viewerId,
        authorId: authorId,
        liked: liked,
      );
      _patch(authorId, liked: liked);
    } finally {
      _updating.remove(authorId);
      notifyListeners();
    }
  }

  Future<void> setReadLater({
    required String viewerId,
    required String authorId,
    required bool readLater,
  }) async {
    if (_updating.contains(authorId)) return;
    _updating.add(authorId);
    notifyListeners();
    try {
      await _service.setReadLaterStatus(
        viewerId: viewerId,
        authorId: authorId,
        readLater: readLater,
      );
      _patch(authorId, readLater: readLater);
    } finally {
      _updating.remove(authorId);
      notifyListeners();
    }
  }

  /// Resolves a pending discovery card and updates the local cache.
  Future<void> resolvePendingCard({
    required String viewerId,
    required String authorId,
    required ActionType action,
  }) async {
    await _service.resolvePendingCard(
      viewerId: viewerId,
      authorId: authorId,
      action: action,
    );
    await _fetch(viewerId, authorId);
  }

  Future<void> markCardAsPending({
    required String viewerId,
    required String authorId,
  }) async {
    await _service.markCardAsPending(viewerId: viewerId, authorId: authorId);
    await _fetch(viewerId, authorId);
  }

  Future<void> recordProfileVisit({
    required String viewerId,
    required String authorId,
  }) async {
    await _service.recordProfileVisit(viewerId: viewerId, authorId: authorId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Applies a partial update to the cached relation without a round-trip.
  void _patch(
    String authorId, {
    bool? subscribed,
    bool? liked,
    bool? readLater,
  }) {
    final existing = _cache[authorId];
    if (existing != null) {
      _cache[authorId] = existing.copyWith(
        subscribed: subscribed,
        liked: liked,
        readLater: readLater,
      );
    } else {
      _cache[authorId] = ViewerAuthorRelation(
        viewerId: '',
        authorId: authorId,
        subscribed: subscribed ?? false,
        liked: liked ?? false,
        readLater: readLater ?? false,
      );
    }
  }

  /// Removes a single entry from the cache (e.g. after sign-out).
  void evict(String authorId) {
    _cache.remove(authorId);
    notifyListeners();
  }

  /// Clears all cached relations — call on sign-out.
  void clear() {
    _cache.clear();
    _updating.clear();
    notifyListeners();
  }
}
