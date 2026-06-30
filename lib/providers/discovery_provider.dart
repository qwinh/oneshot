import 'package:flutter/foundation.dart';
import '../models/prime_content.dart';
import '../services/discovery_service.dart';

/// Owns the state of the Discovery card feed: the candidate list, the
/// current index, loading/error state, and the active tag filter.
/// Screens observe this instead of holding local copies.
class DiscoveryProvider extends ChangeNotifier {
  final DiscoveryService _service = DiscoveryService();

  List<String> _tags = [];

  /// Tags currently applied as a filter. Empty means "no filter" (the
  /// default lazy feed). Combined via [matchAllTags]: OR (any selected tag
  /// matches) or AND (author must carry every selected tag).
  List<String> _selectedTags = [];
  bool _matchAllTags = false;

  List<AuthorProfile> _candidates = [];
  int _currentIndex = 0;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _statusMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  /// All known tags, used as the suggestion source for the tag search field.
  List<String> get tags => _tags;

  List<String> get selectedTags => List.unmodifiable(_selectedTags);
  bool get matchAllTags => _matchAllTags;

  List<AuthorProfile> get candidates => _candidates;
  int get currentIndex => _currentIndex;

  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get statusMessage => _statusMessage;

  AuthorProfile? get currentProfile =>
      _candidates.isNotEmpty && _currentIndex < _candidates.length
      ? _candidates[_currentIndex]
      : null;

  bool get hasMore => _currentIndex < _candidates.length - 1;
  bool get isFeedEmpty => _hasLoadedOnce && _candidates.isEmpty;

  /// Tags matching [query] (substring match) that aren't already selected.
  /// Used to populate the tag search field's suggestion list.
  List<String> tagSuggestions(String query) {
    final String normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return [];
    return _tags
        .where((t) => t.contains(normalized) && !_selectedTags.contains(t))
        .toList();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Call once when the Discovery screen first mounts.
  /// Loads tags and handles interrupted-session recovery.
  Future<void> init(String viewerId) async {
    if (_hasLoadedOnce) return;
    _isLoading = true;
    notifyListeners();

    try {
      _tags = await _service.getAllActiveTags();
      notifyListeners();

      // Interruption recovery (REQ-FUNC-007)
      final pendingId = await _service.findPendingCardAuthorId(viewerId);
      if (pendingId != null) {
        final profile = await _service.getAuthorProfile(pendingId);
        if (profile != null) {
          _candidates = [profile];
          _currentIndex = 0;
          _hasLoadedOnce = true;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      await _loadFeed(viewerId);
    } catch (_) {
      _statusMessage = 'Could not load discovery feed.';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Feed loading ──────────────────────────────────────────────────────────

  /// Reloads the feed using the currently selected tags/match mode.
  Future<void> loadFeed(String viewerId) async {
    await _loadFeed(viewerId);
  }

  Future<void> _loadFeed(String viewerId) async {
    _isLoading = true;
    _statusMessage = null;
    notifyListeners();

    try {
      _candidates = await _service.browseByTags(
        viewerId: viewerId,
        tags: _selectedTags,
        matchAll: _matchAllTags,
      );
      _currentIndex = 0;
      _hasLoadedOnce = true;

      if (_candidates.isEmpty) {
        _statusMessage = _selectedTags.isNotEmpty
            ? 'No more profiles match this tag combination.'
            : 'No more profiles to discover right now.';
      }
    } catch (_) {
      _statusMessage = 'Could not load discovery feed.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  /// Moves to the next candidate, or marks the feed exhausted.
  void advance() {
    if (_currentIndex < _candidates.length - 1) {
      _currentIndex++;
    } else {
      _candidates = [];
      _currentIndex = 0;
      _statusMessage = 'You have reached the end of your discovery queue.';
    }
    notifyListeners();
  }

  // ── Tags ──────────────────────────────────────────────────────────────────

  Future<void> refreshTags() async {
    _tags = await _service.getAllActiveTags();
    notifyListeners();
  }

  /// Adds [tag] to the active filter (no-op if already present) and
  /// reloads the feed.
  Future<void> addTag(String viewerId, String tag) async {
    final String normalized = tag.toLowerCase().trim();
    if (normalized.isEmpty || _selectedTags.contains(normalized)) return;
    _selectedTags = [..._selectedTags, normalized];
    await _loadFeed(viewerId);
  }

  /// Removes [tag] from the active filter and reloads the feed.
  Future<void> removeTag(String viewerId, String tag) async {
    if (!_selectedTags.contains(tag)) return;
    _selectedTags = _selectedTags.where((t) => t != tag).toList();
    await _loadFeed(viewerId);
  }

  /// Clears all selected tags and reloads the (unfiltered) feed.
  Future<void> clearTags(String viewerId) async {
    if (_selectedTags.isEmpty) return;
    _selectedTags = [];
    await _loadFeed(viewerId);
  }

  /// Switches between OR (any selected tag matches) and AND (all selected
  /// tags must match). Only triggers a reload if it would change results
  /// (i.e. 2+ tags are selected — with 0 or 1 tags the mode is moot).
  Future<void> setMatchAllTags(String viewerId, bool matchAll) async {
    if (_matchAllTags == matchAll) return;
    _matchAllTags = matchAll;
    if (_selectedTags.length > 1) {
      await _loadFeed(viewerId);
    } else {
      notifyListeners();
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Full reset — call on sign-out.
  void clear() {
    _tags = [];
    _selectedTags = [];
    _matchAllTags = false;
    _candidates = [];
    _currentIndex = 0;
    _isLoading = false;
    _hasLoadedOnce = false;
    _statusMessage = null;
    notifyListeners();
  }
}
