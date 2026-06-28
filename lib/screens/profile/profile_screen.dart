import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/profile_provider.dart';
import 'package:oneshot/providers/relation_provider.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/post_card.dart';
import '../../widgets/prime_card.dart';

class ProfileScreen extends StatefulWidget {
  final String authorId;

  const ProfileScreen({super.key, required this.authorId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool get _isOwnProfile =>
      context.read<AppAuthProvider>().currentUserId == widget.authorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().currentUserId;

    await context.read<ProfileProvider>().load(widget.authorId);

    if (userId != null && !_isOwnProfile) {
      final rp = context.read<RelationProvider>();
      await rp.load(userId, widget.authorId);
      await rp.recordProfileVisit(viewerId: userId, authorId: widget.authorId);
    }
  }

  Future<void> _refresh() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    await context.read<ProfileProvider>().refresh(widget.authorId);
    if (userId != null && !_isOwnProfile) {
      await context.read<RelationProvider>().refresh(userId, widget.authorId);
    }
  }

  Future<void> _toggleSubscribed() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    final profile = context.read<ProfileProvider>().getProfile(widget.authorId);
    if (userId == null || profile == null) return;

    final rp = context.read<RelationProvider>();
    final currentlySubscribed = rp.isSubscribed(widget.authorId);

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

    try {
      await rp.setSubscribed(
        viewerId: userId,
        authorId: widget.authorId,
        subscribed: !currentlySubscribed,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  Future<void> _toggleLiked() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;

    final rp = context.read<RelationProvider>();
    try {
      await rp.setLiked(
        viewerId: userId,
        authorId: widget.authorId,
        liked: !rp.isLiked(widget.authorId),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    final rp = context.watch<RelationProvider>();

    final profile = pp.getProfile(widget.authorId);
    final works = pp.getWorks(widget.authorId);
    final isLoading = pp.isLoading(widget.authorId);
    final error = pp.getError(widget.authorId);

    final isUpdating = rp.isUpdating(widget.authorId);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(profile?.displayName ?? 'Profile'),
        backgroundColor: kBg,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : error != null
          ? Center(child: Text(error, style: kSubtitleText))
          : profile == null
          ? const Center(
              child: Text(
                'This profile could not be found.',
                style: TextStyle(color: kTextSecondary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              color: kAccent,
              backgroundColor: kSurface,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (profile.hidden)
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
                  if (!_isOwnProfile)
                    _ActionRow(
                      subscribed: rp.isSubscribed(widget.authorId),
                      liked: rp.isLiked(widget.authorId),
                      isUpdating: isUpdating,
                      onToggleSubscribed: _toggleSubscribed,
                      onToggleLiked: _toggleLiked,
                    ),
                  const SizedBox(height: 16),
                  PrimeCard(profile: profile),
                  if (works.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No posts published yet.',
                        style: TextStyle(color: kTextSecondary, fontSize: 13),
                      ),
                    )
                  else
                    ...works.map((work) => PostCard(work: work)),
                ],
              ),
            ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool subscribed;
  final bool liked;
  final bool isUpdating;
  final VoidCallback onToggleSubscribed;
  final VoidCallback onToggleLiked;

  const _ActionRow({
    required this.subscribed,
    required this.liked,
    required this.isUpdating,
    required this.onToggleSubscribed,
    required this.onToggleLiked,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isUpdating ? null : onToggleSubscribed,
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
          onPressed: isUpdating ? null : onToggleLiked,
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
