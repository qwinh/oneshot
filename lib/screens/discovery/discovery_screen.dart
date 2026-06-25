import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/models/relation.dart';
import 'package:oneshot/services/discovery_service.dart';
import 'package:oneshot/services/relation_service.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/action_buttons.dart';
import 'prime_card.dart';
import '../profile/profile_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final RelationService _relationService = RelationService();

  List<String> _tags = [];
  String? _selectedTag;

  List<AuthorProfile> _candidates = [];
  int _currentIndex = 0;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _statusMessage;

  ViewerAuthorRelation? _currentRelation;

  @override
  void initState() {
    super.initState();
    _checkForInterruptedSession();
  }

  Future<void> _checkForInterruptedSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final fetchedTags = await _discoveryService.getAllActiveTags();
      if (mounted) setState(() => _tags = fetchedTags);

      final pendingAuthorId = await _discoveryService.findPendingCardAuthorId(
        user.uid,
      );
      if (pendingAuthorId != null) {
        final profile = await _discoveryService.getAuthorProfile(
          pendingAuthorId,
        );
        if (profile != null) {
          setState(() {
            _candidates = [profile];
            _currentIndex = 0;
            _hasLoadedOnce = true;
          });
          await _markCurrentCardAsPending();
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      await _loadDiscoveryFeed();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDiscoveryFeed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _candidates = [];
      _currentIndex = 0;
      _statusMessage = null;
    });

    try {
      final list = await _discoveryService.browseDiscoverable(
        viewerId: user.uid,
        tag: _selectedTag,
      );

      setState(() {
        _candidates = list;
        _isLoading = false;
        _hasLoadedOnce = true;
        if (list.isEmpty) {
          _statusMessage = _selectedTag == null
              ? 'No new creators are available to discover right now.'
              : 'No new creators matching this tag are available.';
        } else {
          _markCurrentCardAsPending();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
        _statusMessage = 'Error loading discovery: ${e.toString()}';
      });
    }
  }

  void _selectTag(String? tag) {
    if (_selectedTag == tag) return;
    setState(() => _selectedTag = tag);
    _loadDiscoveryFeed();
  }

  Future<void> _markCurrentCardAsPending() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentIndex >= _candidates.length) return;

    final creator = _candidates[_currentIndex];
    await _relationService.markCardAsPending(
      viewerId: user.uid,
      authorId: creator.uid,
    );

    final rel = await _relationService.getRelation(user.uid, creator.uid);
    if (!mounted) return;
    setState(() => _currentRelation = rel);
  }

  Future<void> _handleAction(ActionType action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentIndex >= _candidates.length) return;

    final creator = _candidates[_currentIndex];

    try {
      await _relationService.resolvePendingCard(
        viewerId: user.uid,
        authorId: creator.uid,
        action: action,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Committed action: ${action.name.toUpperCase()}'),
          duration: const Duration(seconds: 1),
        ),
      );

      setState(() {
        _currentIndex++;
        _currentRelation = null;
      });

      if (_currentIndex < _candidates.length) {
        _markCurrentCardAsPending();
      } else {
        setState(() {
          _statusMessage = _selectedTag == null
              ? 'You have discovered all available creators!'
              : 'You have discovered all creators in this tag!';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
    }
  }

  Future<void> _toggleLike(bool isLiked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentIndex >= _candidates.length) return;

    final creator = _candidates[_currentIndex];
    await _relationService.setLikedStatus(
      viewerId: user.uid,
      authorId: creator.uid,
      liked: isLiked,
    );

    setState(() {
      if (_currentRelation != null) {
        _currentRelation = _currentRelation!.copyWith(liked: isLiked);
      }
    });
  }

  Future<void> _triggerProfileView() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentIndex >= _candidates.length) return;

    final creator = _candidates[_currentIndex];
    await _relationService.recordProfileVisit(
      viewerId: user.uid,
      authorId: creator.uid,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(authorId: creator.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('OneShot Discovery'),
        backgroundColor: kBg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDiscoveryFeed,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Browse Creators by Tag',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tags.length + 1,
                      itemBuilder: (context, idx) {
                        if (idx == 0) {
                          final bool isSelected = _selectedTag == null;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: const Text('All'),
                              selected: isSelected,
                              onSelected: (_) => _selectTag(null),
                              backgroundColor: kSurface,
                              selectedColor: kAccent,
                              labelStyle: TextStyle(
                                color: isSelected ? kBg : kTextPrimary,
                              ),
                            ),
                          );
                        }
                        final tag = _tags[idx - 1];
                        final isSelected = _selectedTag == tag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text('#$tag'),
                            selected: isSelected,
                            onSelected: (_) => _selectTag(tag),
                            backgroundColor: kSurface,
                            selectedColor: kAccent,
                            labelStyle: TextStyle(
                              color: isSelected ? kBg : kTextPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: !_hasLoadedOnce
                        ? _buildWelcomeState()
                        : _currentIndex < _candidates.length
                        ? Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: PrimeCard(
                                    profile: _candidates[_currentIndex],
                                  ),
                                ),
                              ),
                              ActionButtons(
                                isLiked: _currentRelation?.liked ?? false,
                                onNext: () => _handleAction(ActionType.next),
                                onSubscribe: () =>
                                    _handleAction(ActionType.subscribe),
                                onReadLater: () =>
                                    _handleAction(ActionType.readLater),
                                onLikeToggled: _toggleLike,
                                onViewProfile: _triggerProfileView,
                              ),
                            ],
                          )
                        : Center(
                            child: Text(
                              _statusMessage ??
                                  'All discovery opportunities complete.',
                              textAlign: TextAlign.center,
                              style: kSubtitleText.copyWith(fontSize: 15),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style_outlined, size: 70, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Loading Discovery...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have one chance to discover each creator. Choose your consuming actions wisely.',
            style: kSubtitleText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
