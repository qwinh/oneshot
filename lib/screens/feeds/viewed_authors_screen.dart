import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/models/relation.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/feed_provider.dart';
import 'package:oneshot/theme/app_theme.dart';
import '../others/profile_screen.dart';

class ViewedAuthorsScreen extends StatefulWidget {
  const ViewedAuthorsScreen({super.key});

  @override
  State<ViewedAuthorsScreen> createState() => _ViewedAuthorsScreenState();
}

class _ViewedAuthorsScreenState extends State<ViewedAuthorsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadViewedAuthorsFeed(userId);
  }

  Future<void> _refresh() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<FeedProvider>().loadViewedAuthorsFeed(userId);
  }

  String _actionLabel(ActionType action) {
    switch (action) {
      case ActionType.subscribe:
        return 'Subscribed';
      case ActionType.next:
        return 'Skipped (Next)';
      case ActionType.readLater:
        return 'Read Later';
      case ActionType.none:
        return 'Unresolved';
    }
  }

  IconData _actionIcon(ActionType action) {
    switch (action) {
      case ActionType.subscribe:
        return Icons.rss_feed;
      case ActionType.next:
        return Icons.skip_next;
      case ActionType.readLater:
        return Icons.bookmark;
      case ActionType.none:
        return Icons.history;
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<FeedProvider>();
    final isLoading = feedProvider.viewedAuthorsLoading;
    final history = feedProvider.viewedAuthorsFeed;
    final error = feedProvider.viewedAuthorsError;

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
              child: history.isEmpty
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
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        final profile = entry.profile;
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
                              child: Icon(
                                _actionIcon(entry.actionType),
                                color: kTextSecondary,
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
                              '@${profile.handle} · ${_actionLabel(entry.actionType)}'
                              '${entry.consumedAt != null ? ' · ${_formatTimestamp(entry.consumedAt)}' : ''}',
                              style: kSubtitleText,
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.white24,
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
          const Icon(Icons.history_toggle_off, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No Interaction History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Authors you encounter in Discovery will appear here.',
            style: kSubtitleText,
          ),
        ],
      ),
    );
  }
}
