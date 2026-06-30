import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/models/relation.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/discovery_provider.dart';
import 'package:oneshot/providers/relation_provider.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/action_buttons.dart';
import '../../widgets/prime_card.dart';
import '../profile/profile_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<DiscoveryProvider>().init(userId);
    await _markCurrentCardAsPending();
  }

  Future<void> _reload() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    final dp = context.read<DiscoveryProvider>();
    await dp.loadFeed(userId, tag: dp.selectedTag);
    await _markCurrentCardAsPending();
  }

  void _selectTag(String? tag) async {
    final dp = context.read<DiscoveryProvider>();
    if (dp.selectedTag == tag) return;
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await dp.loadFeed(userId, tag: tag);
    await _markCurrentCardAsPending();
  }

  Future<void> _markCurrentCardAsPending() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    final dp = context.read<DiscoveryProvider>();
    final relationProvider = context.read<RelationProvider>();
    final profile = dp.currentProfile;
    if (userId == null || profile == null) return;

    await relationProvider.markCardAsPending(
      viewerId: userId,
      authorId: profile.uid,
    );
    await relationProvider.load(userId, profile.uid);
  }

  Future<void> _handleAction(ActionType action) async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    final dp = context.read<DiscoveryProvider>();
    final profile = dp.currentProfile;
    if (userId == null || profile == null) return;

    try {
      await context.read<RelationProvider>().resolvePendingCard(
        viewerId: userId,
        authorId: profile.uid,
        action: action,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Committed action: ${action.name.toUpperCase()}'),
          duration: const Duration(seconds: 1),
        ),
      );

      dp.advance();

      if (dp.currentProfile != null) {
        await _markCurrentCardAsPending();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
    }
  }

  Future<void> _toggleLike(bool liked) async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    final profile = context.read<DiscoveryProvider>().currentProfile;
    if (userId == null || profile == null) return;

    await context.read<RelationProvider>().setLiked(
      viewerId: userId,
      authorId: profile.uid,
      liked: liked,
    );
  }

  Future<void> _openProfile() async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    final profile = context.read<DiscoveryProvider>().currentProfile;
    if (userId == null || profile == null) return;

    await context.read<RelationProvider>().recordProfileVisit(
      viewerId: userId,
      authorId: profile.uid,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(authorId: profile.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DiscoveryProvider>();
    final profile = dp.currentProfile;
    final relation = profile != null
        ? context.watch<RelationProvider>().getRelation(profile.uid)
        : null;

    return Scaffold(
      backgroundColor: kBg,
      body: RefreshIndicator(
        onRefresh: _reload,
        color: kAccent,
        backgroundColor: kSurface,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Tag header
            const Text(
              'Browse Creators by Tag',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _TagRow(
              tags: dp.tags,
              selectedTag: dp.selectedTag,
              onSelect: _selectTag,
            ),
            const SizedBox(height: 24),

            // Content area
            if (dp.isLoading)
              const Center(child: CircularProgressIndicator(color: kAccent))
            else if (!dp.hasLoadedOnce)
              _buildWelcomeState()
            else if (profile == null)
              Center(
                child: Text(
                  dp.statusMessage ?? 'All discovery opportunities complete.',
                  textAlign: TextAlign.center,
                  style: kSubtitleText.copyWith(fontSize: 15),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimeCard(
                    profile: profile,
                    onTapAuthor: (_) => _openProfile(),
                  ),
                  const SizedBox(height: 16),
                  ActionButtons(
                    isLiked: relation?.liked ?? false,
                    onNext: () => _handleAction(ActionType.next),
                    onSubscribe: () => _handleAction(ActionType.subscribe),
                    onReadLater: () => _handleAction(ActionType.readLater),
                    onLikeToggled: _toggleLike,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style_outlined, size: 70, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Loading Discovery...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have one chance to discover each creator. Choose your consuming actions wisely.',
            style: kSubtitleText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onSelect;

  const _TagRow({
    required this.tags,
    required this.selectedTag,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length + 1,
        itemBuilder: (context, idx) {
          if (idx == 0) {
            final bool isSelected = selectedTag == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: const Text('All'),
                selected: isSelected,
                onSelected: (_) => onSelect(null),
                backgroundColor: kSurface,
                selectedColor: kAccent,
                labelStyle: TextStyle(color: isSelected ? kBg : kTextPrimary),
              ),
            );
          }
          final tag = tags[idx - 1];
          final isSelected = selectedTag == tag;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text('#$tag'),
              selected: isSelected,
              onSelected: (_) => onSelect(tag),
              backgroundColor: kSurface,
              selectedColor: kAccent,
              labelStyle: TextStyle(color: isSelected ? kBg : kTextPrimary),
            ),
          );
        },
      ),
    );
  }
}
