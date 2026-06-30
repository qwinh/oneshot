import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/models/relation.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/discovery_provider.dart';
import 'package:oneshot/providers/relation_provider.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/action_buttons.dart';
import '../../widgets/prime_card.dart';
import 'profile_screen.dart';

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
    await context.read<DiscoveryProvider>().loadFeed(userId);
    await _markCurrentCardAsPending();
  }

  Future<void> _addTag(String tag) async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<DiscoveryProvider>().addTag(userId, tag);
    await _markCurrentCardAsPending();
  }

  Future<void> _removeTag(String tag) async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<DiscoveryProvider>().removeTag(userId, tag);
    await _markCurrentCardAsPending();
  }

  Future<void> _setMatchAll(bool matchAll) async {
    final userId = context.read<AppAuthProvider>().currentUserId;
    if (userId == null) return;
    await context.read<DiscoveryProvider>().setMatchAllTags(userId, matchAll);
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
              'Filter Creators by Tag',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _TagFilterField(
              allTags: dp.tags,
              selectedTags: dp.selectedTags,
              matchAll: dp.matchAllTags,
              suggestionsFor: dp.tagSuggestions,
              onAddTag: _addTag,
              onRemoveTag: _removeTag,
              onMatchAllChanged: _setMatchAll,
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

/// Search-to-add tag filter: type to find a tag, tap a suggestion to add it
/// as a chip. Selected tags appear below as removable chips, with an
/// AND/OR toggle shown once 2+ tags are selected.
class _TagFilterField extends StatefulWidget {
  final List<String> allTags;
  final List<String> selectedTags;
  final bool matchAll;
  final List<String> Function(String query) suggestionsFor;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final ValueChanged<bool> onMatchAllChanged;

  const _TagFilterField({
    required this.allTags,
    required this.selectedTags,
    required this.matchAll,
    required this.suggestionsFor,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onMatchAllChanged,
  });

  @override
  State<_TagFilterField> createState() => _TagFilterFieldState();
}

class _TagFilterFieldState extends State<_TagFilterField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {
      _suggestions = widget.suggestionsFor(query);
    });
  }

  void _addTag(String tag) {
    widget.onAddTag(tag);
    _controller.clear();
    setState(() {
      _suggestions = [];
    });
    // Keep focus so the user can keep adding tags without re-tapping in.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field to find and add a tag.
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onQueryChanged,
          style: const TextStyle(color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Search tags to add…',
            hintStyle: const TextStyle(color: kTextSecondary),
            prefixIcon: const Icon(Icons.search, color: kTextSecondary),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),

        // Suggestion list — only shown while there's a non-empty query
        // with matches that aren't already selected.
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, idx) {
                final tag = _suggestions[idx];
                return ListTile(
                  dense: true,
                  title: Text(
                    '#$tag',
                    style: const TextStyle(color: kTextPrimary),
                  ),
                  onTap: () => _addTag(tag),
                );
              },
            ),
          ),

        // Selected tag chips + AND/OR toggle.
        if (widget.selectedTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in widget.selectedTags)
                Chip(
                  label: Text('#$tag'),
                  backgroundColor: kAccent,
                  labelStyle: const TextStyle(color: kBg),
                  deleteIcon: const Icon(Icons.close, size: 16, color: kBg),
                  onDeleted: () => widget.onRemoveTag(tag),
                ),
              if (widget.selectedTags.length > 1)
                _MatchModeToggle(
                  matchAll: widget.matchAll,
                  onChanged: widget.onMatchAllChanged,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Small AND/OR segmented toggle, only relevant once 2+ tags are selected.
class _MatchModeToggle extends StatelessWidget {
  final bool matchAll;
  final ValueChanged<bool> onChanged;

  const _MatchModeToggle({required this.matchAll, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(
            label: 'Any',
            selected: !matchAll,
            onTap: () => onChanged(false),
          ),
          _modeButton(
            label: 'All',
            selected: matchAll,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? kBg : kTextSecondary,
          ),
        ),
      ),
    );
  }
}
