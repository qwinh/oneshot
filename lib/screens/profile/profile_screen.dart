import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/prime_content.dart';
import '../../models/relation.dart';
import '../../models/work.dart';
import '../../services/discovery_service.dart';
import '../../services/relation_service.dart';
import '../discovery/prime_card.dart';

/// Full profile view for a creator: their prime content plus their standard
/// post feed (REQ-FUNC-021 — visible to any viewer who visits directly, not
/// just subscribers), with Subscribe/Unsubscribe and Like/Unlike controls.
///
/// Reaching this screen — from a discovery card's "View Profile", from
/// Search, or from the Viewed/Liked/Read-Later feeds — is always an
/// ancillary action: it records a visit (REQ-FUNC-011) but never consumes
/// the discovery chance (REQ-INT-002). Subscribing/unsubscribing here is
/// likewise independent of the discovery mechanic (REQ-FUNC-012) — it does
/// not touch discovery_consumed, which is set exclusively by the discovery
/// card's own Subscribe/Next/Read Later actions.
class ProfileScreen extends StatefulWidget {
  final String authorId;

  const ProfileScreen({super.key, required this.authorId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final RelationService _relationService = RelationService();

  AuthorProfile? _profile;
  List<Work> _works = [];
  ViewerAuthorRelation? _relation;
  bool _isLoading = true;
  bool _isUpdatingRelation = false;
  String? _errorMessage;

  bool get _isOwnProfile =>
      FirebaseAuth.instance.currentUser?.uid == widget.authorId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _discoveryService.getAuthorProfile(
        widget.authorId,
      );
      final works = await _discoveryService.getAuthorWorks(widget.authorId);

      final user = FirebaseAuth.instance.currentUser;
      ViewerAuthorRelation? relation;
      if (user != null && !_isOwnProfile) {
        relation = await _relationService.getRelation(
          user.uid,
          widget.authorId,
        );
        // REQ-FUNC-011: record the visit for history; this never touches
        // discovery_consumed.
        await _relationService.recordProfileVisit(
          viewerId: user.uid,
          authorId: widget.authorId,
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _works = works;
        _relation = relation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not load this profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSubscribed() async {
    final user = FirebaseAuth.instance.currentUser;
    final profile = _profile;
    if (user == null || profile == null || _isUpdatingRelation) return;

    final bool currentlySubscribed = _relation?.subscribed ?? false;

    // REQ-FUNC-020(2): hidden authors do not accept new subscriptions.
    // Existing subscribers are unaffected and may still unsubscribe.
    if (!currentlySubscribed && profile.hidden) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This creator has hidden their profile and is not accepting new subscriptions.',
          ),
        ),
      );
      return;
    }

    setState(() => _isUpdatingRelation = true);
    try {
      await _relationService.setSubscribedStatus(
        viewerId: user.uid,
        authorId: widget.authorId,
        subscribed: !currentlySubscribed,
      );
      final updated = await _relationService.getRelation(
        user.uid,
        widget.authorId,
      );
      if (!mounted) return;
      setState(() => _relation = updated);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    } finally {
      if (mounted) setState(() => _isUpdatingRelation = false);
    }
  }

  Future<void> _toggleLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isUpdatingRelation) return;

    final bool currentlyLiked = _relation?.liked ?? false;

    setState(() => _isUpdatingRelation = true);
    try {
      await _relationService.setLikedStatus(
        viewerId: user.uid,
        authorId: widget.authorId,
        liked: !currentlyLiked,
      );
      final updated = await _relationService.getRelation(
        user.uid,
        widget.authorId,
      );
      if (!mounted) return;
      setState(() => _relation = updated);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    } finally {
      if (mounted) setState(() => _isUpdatingRelation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.displayName ?? 'Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : _profile == null
          ? const Center(
              child: Text(
                'This profile could not be found.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_profile!.hidden)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'This creator has hidden their profile from new discovery. '
                        'Existing subscribers and history are preserved.',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                      ),
                    ),
                  if (!_isOwnProfile) _buildActionRow(),
                  const SizedBox(height: 16),
                  const Text(
                    'Prime Content',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  PrimeCard(profile: _profile!),
                  const SizedBox(height: 24),
                  const Text(
                    'Posts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (_works.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No standard posts published yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  else
                    ..._works.map(
                      (work) => Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(work.content),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildActionRow() {
    final bool subscribed = _relation?.subscribed ?? false;
    final bool liked = _relation?.liked ?? false;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUpdatingRelation ? null : _toggleSubscribed,
            icon: Icon(subscribed ? Icons.check : Icons.rss_feed),
            label: Text(subscribed ? 'Subscribed' : 'Subscribe'),
            style: OutlinedButton.styleFrom(
              foregroundColor: subscribed ? Colors.greenAccent : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _isUpdatingRelation ? null : _toggleLiked,
          style: OutlinedButton.styleFrom(
            foregroundColor: liked ? Colors.redAccent : Colors.white,
          ),
          child: Icon(liked ? Icons.favorite : Icons.favorite_border),
        ),
      ],
    );
  }
}
