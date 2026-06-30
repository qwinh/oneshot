import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/prime_content.dart';
import '../services/discovery_service.dart';
import 'relation_provider.dart';

class SearchProvider extends ChangeNotifier {
  final DiscoveryService _service = DiscoveryService();
  RelationProvider? _relationProvider;
  int _observedRelationVersion = -1;

  String? _viewerId;
  String _query = '';
  bool _subscribedOnly = false;
  bool _isLoading = false;
  List<AuthorProfile> _results = [];
  Set<String> _subscribedIds = {};
  int _searchGeneration = 0;

  List<AuthorProfile> get results => _results;
  bool get isLoading => _isLoading;
  bool get subscribedOnly => _subscribedOnly;
  String get query => _query;

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
    if (change == null || _viewerId == null || change.viewerId != _viewerId) {
      return;
    }

    if (!_subscribedOnly || change.kind != RelationChangeKind.subscribed) {
      return;
    }

    unawaited(_executeSearch());
  }

  Future<void> search({
    required String viewerId,
    required String query,
    required bool subscribedOnly,
  }) async {
    _viewerId = viewerId;
    _query = query.trim();
    _subscribedOnly = subscribedOnly;
    await _executeSearch();
  }

  Future<void> setSubscribedOnly({
    required String viewerId,
    required bool subscribedOnly,
  }) async {
    _viewerId = viewerId;
    _subscribedOnly = subscribedOnly;
    await _executeSearch();
  }

  Future<void> _executeSearch() async {
    final viewerId = _viewerId;
    if (viewerId == null) return;
    final generation = ++_searchGeneration;

    if (_subscribedOnly && _query.isEmpty) {
      await _loadAllSubscribed(viewerId, generation);
      return;
    }

    if (_query.isEmpty) {
      if (generation != _searchGeneration) return;
      _results = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (_subscribedOnly) {
        _subscribedIds = await _service.getSubscribedAuthorIds(viewerId);
      }

      final list = await _service.searchAuthors(_query);
      if (generation != _searchGeneration) return;
      _results = _subscribedOnly
          ? list.where((p) => _subscribedIds.contains(p.uid)).toList()
          : list;
    } catch (_) {
      if (generation != _searchGeneration) return;
      _results = [];
    }
    if (generation != _searchGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadAllSubscribed(String viewerId, int generation) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.getSubscribedAuthors(viewerId);
      if (generation != _searchGeneration) return;
      _results = result;
    } catch (_) {
      if (generation != _searchGeneration) return;
      _results = [];
    }
    if (generation != _searchGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _relationProvider?.removeListener(_handleRelationChange);
    super.dispose();
  }

  void clear() {
    _viewerId = null;
    _query = '';
    _subscribedOnly = false;
    _isLoading = false;
    _results = [];
    _subscribedIds = {};
    _searchGeneration++;
    notifyListeners();
  }
}
