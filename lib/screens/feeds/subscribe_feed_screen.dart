import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/feed_provider.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/post_card.dart';
import '../composer/compose_post_screen.dart';
import '../profile/profile_screen.dart';

class SubscribeFeedScreen extends StatefulWidget {
  const SubscribeFeedScreen({super.key});

  @override
  State<SubscribeFeedScreen> createState() => _SubscribeFeedScreenState();
}

class _SubscribeFeedScreenState extends State<SubscribeFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadSubscribeFeed(userId);
  }

  Future<void> _refresh() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadSubscribeFeed(userId);
  }

  void _openAuthorProfile(String authorId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(authorId: authorId)),
    );
  }

  void _composePost() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ComposePostScreen()))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<FeedProvider>();
    final isLoading = feedProvider.subscribeFeedLoading;
    final works = feedProvider.subscribeFeed;
    final error = feedProvider.subscribeFeedError;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Subscribe Feed'),
        backgroundColor: kBg,
        elevation: 0,
        // Removed refresh and edit actions
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : error != null
          ? Center(
              child: Text(
                error,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : works.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refresh,
              color: kAccent,
              backgroundColor: kSurface,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: works.length,
                itemBuilder: (context, index) {
                  final work = works[index];
                  return PostCard(work: work, onTapAuthor: _openAuthorProfile);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _composePost,
        backgroundColor: kAccent,
        child: const Icon(Icons.edit, color: kBg),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rss_feed, size: 60, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Your Subscribe Feed is Empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover creators through the tag directory and tap Subscribe to see their ongoing posts here.',
              style: kSubtitleText,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
