import 'package:flutter/foundation.dart';
import '../models/prime_content.dart';
import '../models/work.dart';
import '../services/discovery_service.dart';

/// Owns the state for all four derived feeds:
///   • Subscribe Feed   (list of Work from subscribed authors)
///   • Read Later Feed  (list of AuthorProfile)
///   • Viewed Authors   (list of ViewedAuthorResult)
///   • Liked Authors    (list of AuthorProfile)
///
/// Each feed has its own loading flag and error message so screens can
/// independently show spinners without coupling to each other.
class FeedProvider extends ChangeNotifier {
  final DiscoveryService _service = DiscoveryService();

  // ── Subscribe Feed ────────────────────────────────────────────────────────
  List<Work> subscribeFeed = [];
  bool subscribeFeedLoading = false;
  String? subscribeFeedError;

  Future<void> loadSubscribeFeed(String viewerId) async {
    subscribeFeedLoading = true;
    subscribeFeedError = null;
    notifyListeners();
    try {
      subscribeFeed = await _service.getSubscribeFeed(viewerId);
    } catch (e) {
      subscribeFeedError = 'Could not load subscribe feed.';
    } finally {
      subscribeFeedLoading = false;
      notifyListeners();
    }
  }

  // ── Read Later Feed ───────────────────────────────────────────────────────
  List<AuthorProfile> readLaterFeed = [];
  bool readLaterLoading = false;
  String? readLaterError;

  Future<void> loadReadLaterFeed(String viewerId) async {
    readLaterLoading = true;
    readLaterError = null;
    notifyListeners();
    try {
      readLaterFeed = await _service.getReadLaterFeed(viewerId);
    } catch (e) {
      readLaterError = 'Could not load read later feed.';
    } finally {
      readLaterLoading = false;
      notifyListeners();
    }
  }

  // ── Viewed Authors Feed ───────────────────────────────────────────────────
  List<ViewedAuthorResult> viewedAuthorsFeed = [];
  bool viewedAuthorsLoading = false;
  String? viewedAuthorsError;

  Future<void> loadViewedAuthorsFeed(String viewerId) async {
    viewedAuthorsLoading = true;
    viewedAuthorsError = null;
    notifyListeners();
    try {
      viewedAuthorsFeed = await _service.getViewedAuthorsFeed(viewerId);
    } catch (e) {
      viewedAuthorsError = 'Could not load viewed authors feed.';
    } finally {
      viewedAuthorsLoading = false;
      notifyListeners();
    }
  }

  // ── Liked Authors Feed ────────────────────────────────────────────────────
  List<AuthorProfile> likedAuthorsFeed = [];
  bool likedAuthorsLoading = false;
  String? likedAuthorsError;

  Future<void> loadLikedAuthorsFeed(String viewerId) async {
    likedAuthorsLoading = true;
    likedAuthorsError = null;
    notifyListeners();
    try {
      likedAuthorsFeed = await _service.getLikedAuthorsFeed(viewerId);
    } catch (e) {
      likedAuthorsError = 'Could not load liked authors feed.';
    } finally {
      likedAuthorsLoading = false;
      notifyListeners();
    }
  }

  // ── Convenience ───────────────────────────────────────────────────────────

  /// Removes an author from the read-later list locally after the viewer
  /// acts on it (e.g. via RelationProvider.setReadLater(false)), so the
  /// feed updates without a full reload.
  void evictFromReadLater(String authorId) {
    readLaterFeed.removeWhere((p) => p.uid == authorId);
    notifyListeners();
  }

  void evictFromLiked(String authorId) {
    likedAuthorsFeed.removeWhere((p) => p.uid == authorId);
    notifyListeners();
  }

  /// Full reset — call on sign-out.
  void clear() {
    subscribeFeed = [];
    readLaterFeed = [];
    viewedAuthorsFeed = [];
    likedAuthorsFeed = [];
    subscribeFeedLoading = false;
    readLaterLoading = false;
    viewedAuthorsLoading = false;
    likedAuthorsLoading = false;
    subscribeFeedError = null;
    readLaterError = null;
    viewedAuthorsError = null;
    likedAuthorsError = null;
    notifyListeners();
  }
}
