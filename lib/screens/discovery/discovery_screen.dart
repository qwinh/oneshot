import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/prime_content.dart';
import '../../models/relation.dart';
import '../../services/discovery_service.dart';
import '../../services/relation_service.dart';
import '../../widgets/action_buttons.dart';
import 'prime_card.dart';
v
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
  String? _statusMessage;
  
  // Real-time tracking of current card relationship
  ViewerAuthorRelation? _currentRelation;

  @override
  void initState() {
    super.initState();
    _checkForInterruptedSession();
  }

  /// REQ-FUNC-007 (Interruption handling recovery)
  /// Checks on load if the user abandoned an active discovery encounter in their last session.
  Future<void> _checkForInterruptedSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Clean recovery using your findPendingCardAuthorId service method
      final pendingAuthorId = await _discoveryService.findPendingCardAuthorId(user.uid);
      
      if (pendingAuthorId != null) {
        final profile = await _discoveryService.getAuthorProfile(pendingAuthorId);
        if (profile != null) {
          setState(() {
            _candidates = [profile];
            _currentIndex = 0;
            _selectedTag = profile.tags.isNotEmpty ? profile.tags.first : 'Interrupted';
          });
          await _markCurrentCardAsPending();
        }
      }
      
      // Load all available browse tags
      final fetchedTags = await _discoveryService.getAllActiveTags();
      setState(() {
        _tags = fetchedTags;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTagDiscovery(String tag) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _selectedTag = tag;
      _candidates = [];
      _currentIndex = 0;
      _statusMessage = null;
    });

    try {
      // Corrected to use your optimized browseByTag method signature
      final list = await _discoveryService.browseByTag(
        viewerId: user.uid,
        tag: tag,
      );

      setState(() {
        _candidates = list;
        _isLoading = false;
        if (list.isEmpty) {
          _statusMessage = 'No new creators matching this tag are available.';
        } else {
          // Immediately flag the first card as PENDING to implement Interruption handling
          _markCurrentCardAsPending();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading discovery: ${e.toString()}';
      });
    }
  }

  /// REQ-FUNC-007: Mark the currently shown card as pending
  Future<void> _markCurrentCardAsPending() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentIndex >= _candidates.length) return;

    final creator = _candidates[_currentIndex];
    await _relationService.markCardAsPending(
      viewerId: user.uid,
      authorId: creator.uid,
    );

    // Stream/fetch updated relation row
    final rel = await _relationService.getRelation(user.uid, creator.uid);
    setState(() {
      _currentRelation = rel;
    });
  }

  /// Executes atomic resolution (Subscribe, Next, Read Later) and steps the card deck index
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

      // Step index to next candidate
      setState(() {
        _currentIndex++;
        _currentRelation = null;
      });

      if (_currentIndex < _candidates.length) {
        _markCurrentCardAsPending();
      } else {
        setState(() {
          _statusMessage = 'You have discovered all creators in this tag!';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}')),
      );
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

  void _triggerProfileView() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile visited (Ancillary Action - discovery preserved)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneShot Discovery'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Horizontal Tag Browsing list (REQ-FUNC-006)
                  const Text(
                    'Browse Creators by Tag',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: _tags.isEmpty
                        ? const Center(child: Text('No active tags populated yet.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _tags.length,
                            itemBuilder: (context, idx) {
                              final tag = _tags[idx];
                              final isSelected = _selectedTag == tag;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text('#$tag'),
                                  selected: isSelected,
                                  onSelected: (_) => _loadTagDiscovery(tag),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Discovery Card Slot
                  Expanded(
                    child: _selectedTag == null
                        ? _buildWelcomeState()
                        : _currentIndex < _candidates.length
                            ? Column(
                                children: [
                                  Expanded(
                                    child: PrimeCard(profile: _candidates[_currentIndex]),
                                  ),
                                  ActionButtons(
                                    isLiked: _currentRelation?.liked ?? false,
                                    onNext: () => _handleAction(ActionType.next),
                                    onSubscribe: () => _handleAction(ActionType.subscribe),
                                    onReadLater: () => _handleAction(ActionType.readLater),
                                    onLikeToggled: _toggleLike,
                                    onViewProfile: _triggerProfileView,
                                  ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  _statusMessage ?? 'All discovery opportunities complete.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey, fontSize: 15),
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
            'Select a Tag to Start',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You have one chance to discover each creator. Choose your consuming actions wisely.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}