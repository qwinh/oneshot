import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/services/discovery_service.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'block_controller.dart';
import 'composer_app_bar.dart';
import 'composer_feedback.dart';
import 'composer_widgets.dart';

class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key});

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();

  late final BlockController _blockController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _blockController = BlockController(
      imageFilePrefix: 'post',
      onStateChanged: () => setState(() {}),
      onError: (msg) {
        if (mounted) showComposerSnack(context, msg, isError: true);
      },
    );
  }

  @override
  void dispose() {
    _blockController.dispose();
    super.dispose();
  }

  // ── Publish ───────────────────────────────────────────────────────────────

  Future<void> _publish() async {
    final trimmedBlocks = _blockController.trimmedBlocks;

    if (trimmedBlocks.isEmpty) {
      setState(() => _errorMessage = 'Add some content before publishing.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = await _discoveryService.getAuthorProfile(user.uid);
    if (profile == null) {
      setState(
        () => _errorMessage = 'You need a profile first. Set up your Prime.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _discoveryService.publishWork(
        authorId: user.uid,
        authorName: profile.displayName,
        authorHandle: profile.handle,
        blocks: trimmedBlocks,
      );
      if (mounted) {
        showComposerSnack(context, 'Post published!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: ComposerAppBar(
        title: 'New Post',
        isSaving: _isSaving,
        onPublish: _publish,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(message: _errorMessage),
            const SizedBox(height: 12),
            BlockComposer(
              controller: _blockController,
              firstBlockHint: "What's on your mind?",
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
