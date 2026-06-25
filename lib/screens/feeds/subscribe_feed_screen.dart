import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/models/work.dart';
import 'package:oneshot/services/discovery_service.dart';
import 'package:oneshot/theme/app_theme.dart';

class SubscribeFeedScreen extends StatefulWidget {
  const SubscribeFeedScreen({super.key});

  @override
  State<SubscribeFeedScreen> createState() => _SubscribeFeedScreenState();
}

class _SubscribeFeedScreenState extends State<SubscribeFeedScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final TextEditingController _workController = TextEditingController();

  List<Work> _works = [];
  bool _isLoading = false;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  @override
  void dispose() {
    _workController.dispose();
    super.dispose();
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

  Future<void> _publishWork() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _workController.text.trim().isEmpty) return;

    setState(() => _isPublishing = true);

    try {
      final profile = await _discoveryService.getAuthorProfile(user.uid);
      final displayName = profile?.displayName ?? 'Anonymous';
      final handle = profile?.handle ?? 'anonymous';

      await _discoveryService.publishWork(
        authorId: user.uid,
        authorName: displayName,
        authorHandle: handle,
        content: _workController.text.trim(),
      );

      _workController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work published successfully!'),
            backgroundColor: kSuccess,
          ),
        );
      }
      await _fetchFeed();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
    } finally {
      setState(() => _isPublishing = false);
    }
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : Column(
              children: [
                _buildPublishWidget(),
                const Divider(height: 1, color: kBorder),
                Expanded(
                  child: _works.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _works.length,
                          itemBuilder: (context, index) {
                            final work = _works[index];
                            return Card(
                              color: kSurface,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: kBorder),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          work.authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${work.createdAt.hour}:${work.createdAt.minute.toString().padLeft(2, '0')}',
                                          style: kSubtitleText.copyWith(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${work.authorHandle}',
                                      style: kSubtitleText.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(work.content, style: kBodyText),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildPublishWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: kSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Demo Area: Publish Update (Subscribers will see this)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _workController,
                  maxLines: 2,
                  style: const TextStyle(color: kTextPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Share a regular text post update...',
                    hintStyle: kSubtitleText.copyWith(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isPublishing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kAccent,
                      ),
                    )
                  : IconButton(
                      onPressed: _publishWork,
                      icon: const Icon(Icons.send, color: kTextPrimary),
                      style: IconButton.styleFrom(backgroundColor: kBorder),
                    ),
            ],
          ),
        ],
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
