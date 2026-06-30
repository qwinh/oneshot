import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/feed_provider.dart';
import 'package:oneshot/providers/relation_provider.dart';
import 'package:oneshot/theme/app_theme.dart';
import '../../widgets/prime_card.dart';
import '../profile/profile_screen.dart';

class ReadLaterScreen extends StatefulWidget {
  const ReadLaterScreen({super.key});

  @override
  State<ReadLaterScreen> createState() => _ReadLaterScreenState();
}

class _ReadLaterScreenState extends State<ReadLaterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadReadLaterFeed(userId);
  }

  Future<void> _refresh() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadReadLaterFeed(userId);
  }

  Future<void> _removeFromReadLater(String authorId) async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;

    try {
      await context.read<RelationProvider>().setReadLater(
        viewerId: userId,
        authorId: authorId,
        readLater: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from Read Later shelf'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  void _viewSavedCard(AuthorProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: PrimeCard(profile: profile),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileScreen(authorId: profile.uid),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.person_outline,
                              color: kTextPrimary,
                            ),
                            label: const Text(
                              'View Full Profile',
                              style: TextStyle(color: kTextPrimary),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _removeFromReadLater(profile.uid);
                            },
                            icon: const Icon(
                              Icons.bookmark_remove,
                              color: kDestructive,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(color: kDestructive),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<FeedProvider>();
    final isLoading = feedProvider.readLaterLoading;
    final savedProfiles = feedProvider.readLaterFeed;
    final error = feedProvider.readLaterError;

    return Scaffold(
      backgroundColor: kBg,
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
              child: savedProfiles.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height - 150,
                        alignment: Alignment.center,
                        child: _buildEmptyState(),
                      ),
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.1,
                          ),
                      itemCount: savedProfiles.length,
                      itemBuilder: (context, index) {
                        final profile = savedProfiles[index];
                        return GestureDetector(
                          onTap: () => _viewSavedCard(profile),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(
                                      Icons.bookmark,
                                      color: Colors.orangeAccent,
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white38,
                                        size: 20,
                                      ),
                                      tooltip: 'Remove',
                                      onPressed: () =>
                                          _removeFromReadLater(profile.uid),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: kTextPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${profile.handle}',
                                      style: kSubtitleText.copyWith(
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bookmarks_outlined,
              size: 60,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Read Later Shelf is Empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Save discovery cards to your shelf during browsing to read their full contents later.",
              style: kSubtitleText,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
