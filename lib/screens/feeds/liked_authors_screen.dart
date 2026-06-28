import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/feed_provider.dart';
import 'package:oneshot/theme/app_theme.dart';
import '../profile/profile_screen.dart';

class LikedAuthorsScreen extends StatefulWidget {
  const LikedAuthorsScreen({super.key});

  @override
  State<LikedAuthorsScreen> createState() => _LikedAuthorsScreenState();
}

class _LikedAuthorsScreenState extends State<LikedAuthorsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadLikedAuthorsFeed(userId);
  }

  Future<void> _refresh() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadLikedAuthorsFeed(userId);
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<FeedProvider>();
    final isLoading = feedProvider.likedAuthorsLoading;
    final likes = feedProvider.likedAuthorsFeed;
    final error = feedProvider.likedAuthorsError;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Liked Authors'),
        backgroundColor: kBg,
        elevation: 0,
        // Removed refresh action
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
          : RefreshIndicator(
              onRefresh: _refresh,
              color: kAccent,
              backgroundColor: kSurface,
              child: likes.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height - 150,
                        alignment: Alignment.center,
                        child: _buildEmptyState(),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: likes.length,
                      itemBuilder: (context, index) {
                        final profile = likes[index];
                        return Card(
                          color: kSurface,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: kBorder),
                          ),
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfileScreen(authorId: profile.uid),
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: kBorder,
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '@${profile.handle}',
                              style: kSubtitleText,
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No Liked Authors Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Authors you mark with a like will appear here.",
            style: kSubtitleText,
          ),
        ],
      ),
    );
  }
}
