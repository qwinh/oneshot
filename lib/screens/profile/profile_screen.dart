import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/models/relation.dart';
import 'package:oneshot/models/work.dart';
import 'package:oneshot/services/discovery_service.dart';
import 'package:oneshot/services/relation_service.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/post_card.dart'; // ✅ added
import '../../widgets/prime_card.dart';

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
      final profile = await _discoveryService.getAuthorProfile(widget.authorId);
      final works = await _discoveryService.getAuthorWorks(widget.authorId);

      final user = FirebaseAuth.instance.currentUser;
      ViewerAuthorRelation? relation;
      if (user != null && !_isOwnProfile) {
        relation = await _relationService.getRelation(
          user.uid,
          widget.authorId,
        );
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
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(_profile?.displayName ?? 'Profile'),
        backgroundColor: kBg,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: kSubtitleText))
          : _profile == null
          ? const Center(
              child: Text(
                'This profile could not be found.',
                style: TextStyle(color: kTextSecondary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: kAccent,
              backgroundColor: kSurface,
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
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (!_isOwnProfile) _buildActionRow(),
                  const SizedBox(height: 16),
                  PrimeCard(profile: _profile!),
                  if (_works.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No posts published yet.',
                        style: TextStyle(color: kTextSecondary, fontSize: 13),
                      ),
                    )
                  else
                    ..._works.map((work) => PostCard(work: work)),
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
              foregroundColor: subscribed ? kSuccess : kTextPrimary,
              side: const BorderSide(color: kBorder),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _isUpdatingRelation ? null : _toggleLiked,
          style: OutlinedButton.styleFrom(
            foregroundColor: liked ? Colors.redAccent : kTextPrimary,
            side: const BorderSide(color: kBorder),
          ),
          child: Icon(liked ? Icons.favorite : Icons.favorite_border),
        ),
      ],
    );
  }
}
