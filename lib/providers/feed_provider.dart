import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/prime_content.dart';
import '../models/relation.dart';
import '../models/work.dart';
import '../services/discovery_service.dart';
import 'relation_provider.dart';

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
  RelationProvider? _relationProvider;
  int _observedRelationVersion = -1;
  String? _activeViewerId;
  int _subscribeGeneration = 0;
  int _readLaterGeneration = 0;
  int _viewedAuthorsGeneration = 0;
  int _likedAuthorsGeneration = 0;

  // Subscribe Feed
  List<Work> subscribeFeed = [];
  bool subscribeFeedLoading = false;
  String? subscribeFeedError;

  // Read Later Feed
  List<AuthorProfile> readLaterFeed = [];
  bool readLaterLoading = false;
  String? readLaterError;

  // Viewed Authors Feed
  List<ViewedAuthorResult> viewedAuthorsFeed = [];
  bool viewedAuthorsLoading = false;
  String? viewedAuthorsError;

  // Liked Authors Feed
  List<AuthorProfile> likedAuthorsFeed = [];
  bool likedAuthorsLoading = false;
  String? likedAuthorsError;

  void attachRelationProvider(RelationProvider? relationProvider) {
    if (identical(_relationProvider, relationProvider)) return;
    _relationProvider?.removeListener(_handleRelationChange);
    _relationProvider = relationProvider;
    _relationProvider?.addListener(_handleRelationChange);
  }

  void _handleRelationChange() {
    final relationProvider = _relationProvider;
    if (relationProvider == null) return;

    final version = relationProvider.changeVersion;
    if (version == _observedRelationVersion) return;
    _observedRelationVersion = version;

    final change = relationProvider.lastChange;
    final viewerId = _activeViewerId;
    if (change == null || viewerId == null || change.viewerId != viewerId) {
      return;
    }

    unawaited(_refreshForChange(change));
  }

  Future<void> _refreshForChange(RelationChange change) async {
    switch (change.kind) {
      case RelationChangeKind.subscribed:
        await loadSubscribeFeed(change.viewerId);
        break;
      case RelationChangeKind.liked:
        await loadLikedAuthorsFeed(change.viewerId);
        break;
      case RelationChangeKind.readLater:
        await loadReadLaterFeed(change.viewerId);
        break;
      case RelationChangeKind.discovery:
        if (change.action == ActionType.subscribe) {
          await loadSubscribeFeed(change.viewerId);
        } else if (change.action == ActionType.readLater) {
          await loadReadLaterFeed(change.viewerId);
        }
        await loadViewedAuthorsFeed(change.viewerId);
        break;
    }
  }

  Future<void> loadSubscribeFeed(String viewerId) async {
    _activeViewerId = viewerId;
    final generation = ++_subscribeGeneration;
    subscribeFeedLoading = true;
    subscribeFeedError = null;
    notifyListeners();
    try {
      final result = await _service.getSubscribeFeed(viewerId);
      if (generation != _subscribeGeneration) return;
      subscribeFeed = result;
    } catch (_) {
      if (generation != _subscribeGeneration) return;
      subscribeFeedError = 'Could not load subscribe feed.';
    }
    if (generation != _subscribeGeneration) return;
    subscribeFeedLoading = false;
    notifyListeners();
  }

  Future<void> loadReadLaterFeed(String viewerId) async {
    _activeViewerId = viewerId;
    final generation = ++_readLaterGeneration;
    readLaterLoading = true;
    readLaterError = null;
    notifyListeners();
    try {
      final result = await _service.getReadLaterFeed(viewerId);
      if (generation != _readLaterGeneration) return;
      readLaterFeed = result;
    } catch (_) {
      if (generation != _readLaterGeneration) return;
      readLaterError = 'Could not load read later feed.';
    }
    if (generation != _readLaterGeneration) return;
    readLaterLoading = false;
    notifyListeners();
  }

  Future<void> loadViewedAuthorsFeed(String viewerId) async {
    _activeViewerId = viewerId;
    final generation = ++_viewedAuthorsGeneration;
    viewedAuthorsLoading = true;
    viewedAuthorsError = null;
    notifyListeners();
    try {
      final result = await _service.getViewedAuthorsFeed(viewerId);
      if (generation != _viewedAuthorsGeneration) return;
      viewedAuthorsFeed = result;
    } catch (_) {
      if (generation != _viewedAuthorsGeneration) return;
      viewedAuthorsError = 'Could not load viewed authors feed.';
    }
    if (generation != _viewedAuthorsGeneration) return;
    viewedAuthorsLoading = false;
    notifyListeners();
  }

  Future<void> loadLikedAuthorsFeed(String viewerId) async {
    _activeViewerId = viewerId;
    final generation = ++_likedAuthorsGeneration;
    likedAuthorsLoading = true;
    likedAuthorsError = null;
    notifyListeners();
    try {
      final result = await _service.getLikedAuthorsFeed(viewerId);
      if (generation != _likedAuthorsGeneration) return;
      likedAuthorsFeed = result;
    } catch (_) {
      if (generation != _likedAuthorsGeneration) return;
      likedAuthorsError = 'Could not load liked authors feed.';
    }
    if (generation != _likedAuthorsGeneration) return;
    likedAuthorsLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _relationProvider?.removeListener(_handleRelationChange);
    super.dispose();
  }

  /// Full reset - call on sign-out.
  void clear() {
    _activeViewerId = null;
    _observedRelationVersion = -1;
    _subscribeGeneration++;
    _readLaterGeneration++;
    _viewedAuthorsGeneration++;
    _likedAuthorsGeneration++;
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
