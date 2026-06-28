import 'package:flutter/foundation.dart';
import '../models/prime_content.dart';
import '../services/discovery_service.dart';

/// Owns the state of the Discovery card feed: the candidate list, the
/// current index, loading/error state, and the active tag filter.
/// Screens observe this instead of holding local copies.
class DiscoveryProvider extends ChangeNotifier {
  final DiscoveryService _service = DiscoveryService();

  List<String> _tags = [];
  String? _selectedTag;

  List<AuthorProfile> _candidates = [];
  int _currentIndex = 0;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _statusMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<String> get tags => _tags;
  String? get selectedTag => _selectedTag;

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

  Future<void> loadFeed(String viewerId, {String? tag}) async {
    _selectedTag = tag;
    await _loadFeed(viewerId);
  }

  Future<void> _loadFeed(String viewerId) async {
    _isLoading = true;
    _statusMessage = null;
    notifyListeners();

    try {
      _candidates = await _service.browseDiscoverable(
        viewerId: viewerId,
        tag: _selectedTag,
      );
      _currentIndex = 0;
      _hasLoadedOnce = true;

      if (_candidates.isEmpty) {
        _statusMessage = _selectedTag != null
            ? 'No more profiles in this category.'
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

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Full reset — call on sign-out.
  void clear() {
    _tags = [];
    _selectedTag = null;
    _candidates = [];
    _currentIndex = 0;
    _isLoading = false;
    _hasLoadedOnce = false;
    _statusMessage = null;
    notifyListeners();
  }
}
