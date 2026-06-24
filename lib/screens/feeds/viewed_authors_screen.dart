import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/relation.dart';
import '../../services/discovery_service.dart';
import '../profile/profile_screen.dart';

class ViewedAuthorsScreen extends StatefulWidget {
  const ViewedAuthorsScreen({super.key});

  @override
  State<ViewedAuthorsScreen> createState() => _ViewedAuthorsScreenState();
}

class _ViewedAuthorsScreenState extends State<ViewedAuthorsScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();

  List<ViewedAuthorResult> _history = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final list = await _discoveryService.getViewedAuthorsFeed(user.uid);
      setState(() {
        _history = list;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viewed History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh History',
            onPressed: _fetchFeed,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: Colors.grey[900],
              onRefresh: _fetchFeed,
              child: _history.isEmpty
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
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final entry = _history[index];
                        final profile = entry.profile;
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfileScreen(authorId: profile.uid),
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[800],
                              child: Icon(
                                _actionIcon(entry.actionType),
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '@${profile.handle} · ${_actionLabel(entry.actionType)}'
                              '${entry.consumedAt != null ? ' · ${_formatTimestamp(entry.consumedAt)}' : ''}',
                              style: const TextStyle(color: Colors.grey),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Authors you encounter in Discovery will appear here.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
