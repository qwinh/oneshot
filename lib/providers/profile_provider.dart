import 'package:flutter/foundation.dart';
import '../models/prime_content.dart';
import '../models/work.dart';
import '../services/discovery_service.dart';
import '../services/content_service.dart';

class _ProfileEntry {
  final AuthorProfile profile;
  final List<Work> works;
  const _ProfileEntry(this.profile, this.works);
}

/// Caches author profiles and their work lists so that navigating between
/// ProfileScreen instances (e.g. from Discovery → Profile → back) does not
/// re-fetch on every visit.
class ProfileProvider extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final ContentService _contentService = ContentService();

  final Map<String, _ProfileEntry> _cache = {};
  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};

  // ── Getters ───────────────────────────────────────────────────────────────

  AuthorProfile? getProfile(String authorId) => _cache[authorId]?.profile;
  List<Work> getWorks(String authorId) => _cache[authorId]?.works ?? [];
  bool isLoading(String authorId) => _loading[authorId] ?? false;
  String? getError(String authorId) => _errors[authorId];

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load(String authorId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(authorId)) return;
    if (_loading[authorId] == true) return;

    _loading[authorId] = true;
    _errors[authorId] = null;
    notifyListeners();

    try {
      final profile = await _discoveryService.getAuthorProfile(authorId);
      if (profile == null) {
        _errors[authorId] = 'Profile not found.';
        return;
      }
      final works = await _discoveryService.getAuthorWorks(authorId);
      _cache[authorId] = _ProfileEntry(profile, works);
    } catch (e) {
      _errors[authorId] = 'Could not load profile.';
    } finally {
      _loading[authorId] = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String authorId) => load(authorId, forceRefresh: true);

  Future<bool> isHandleTaken(String handle, {String? excludingUid}) {
    return _contentService.isHandleTaken(handle, excludingUid: excludingUid);
  }

  /// Updates the cached profile after an edit (e.g. from EditPrimeScreen).
  Future<void> saveProfile(AuthorProfile profile) async {
    final bool handleTaken = await isHandleTaken(
      profile.handle,
      excludingUid: profile.uid,
    );
    if (handleTaken) {
      throw StateError('That handle is already taken.');
    }

    await _contentService.saveAuthorProfile(profile);
    final works = _cache[profile.uid]?.works ?? [];
    _cache[profile.uid] = _ProfileEntry(profile, works);
    notifyListeners();
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void evict(String authorId) {
    _cache.remove(authorId);
    _loading.remove(authorId);
    _errors.remove(authorId);
    notifyListeners();
  }

  void clear() {
    _cache.clear();
    _loading.clear();
    _errors.clear();
    notifyListeners();
  }
}
