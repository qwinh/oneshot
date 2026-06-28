import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/models/work.dart';
import 'package:oneshot/services/discovery_service.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/post_card.dart';
import '../composer/compose_post_screen.dart';
import '../profile/profile_screen.dart'; // for navigation

class SubscribeFeedScreen extends StatefulWidget {
  const SubscribeFeedScreen({super.key});

  @override
  State<SubscribeFeedScreen> createState() => _SubscribeFeedScreenState();
}

class _SubscribeFeedScreenState extends State<SubscribeFeedScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();

  List<Work> _works = [];
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
      final list = await _discoveryService.getSubscribeFeed(user.uid);
      setState(() => _works = list);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading feed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openAuthorProfile(String authorId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(authorId: authorId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Subscribe Feed'),
        backgroundColor: kBg,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchFeed),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'New Post',
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => const ComposePostScreen(),
                    ),
                  )
                  .then((_) => _fetchFeed());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _works.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _works.length,
              itemBuilder: (context, index) {
                final work = _works[index];
                return PostCard(
                  work: work,
                  onTapAuthor: _openAuthorProfile, // <-- enables tap
                );
              },
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
