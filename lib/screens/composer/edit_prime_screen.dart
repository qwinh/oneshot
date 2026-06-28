import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/services/content_service.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'block_controller.dart';
import 'composer_app_bar.dart';
import 'composer_feedback.dart';
import 'composer_widgets.dart';

class EditPrimeScreen extends StatefulWidget {
  const EditPrimeScreen({super.key});

  @override
  State<EditPrimeScreen> createState() => _EditPrimeScreenState();
}

class _EditPrimeScreenState extends State<EditPrimeScreen> {
  final ContentService _contentService = ContentService();

  final TextEditingController _handleController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  late BlockController _blockController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  DateTime? _existingCreatedAt;

  @override
  void initState() {
    super.initState();
    _blockController = BlockController(
      imageFilePrefix: 'prime',
      onStateChanged: () => setState(() {}),
      onError: (msg) {
        if (mounted) showComposerSnack(context, msg, isError: true);
      },
    );
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _handleController.dispose();
    _nameController.dispose();
    _tagsController.dispose();
    _blockController.dispose();
    super.dispose();
  }

  // ── Data load ─────────────────────────────────────────────────────────────

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await _contentService.getProfile(user.uid);
      if (profile != null && mounted) {
        // Re-create the controller with the loaded blocks.
        _blockController.dispose();
        _blockController = BlockController(
          initialBlocks: profile.primeBlocks,
          imageFilePrefix: 'prime',
          onStateChanged: () => setState(() {}),
          onError: (msg) {
            if (mounted) showComposerSnack(context, msg, isError: true);
          },
        );
        setState(() {
          _handleController.text = profile.handle;
          _nameController.text = profile.displayName;
          _tagsController.text = profile.tags.join(', ');
          _existingCreatedAt = profile.createdAt;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Could not load profile.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final handle = _handleController.text.trim();
    final displayName = _nameController.text.trim();

    if (handle.isEmpty) {
      setState(() => _errorMessage = 'Handle is required.');
      return;
    }
    if (handle.contains(' ')) {
      setState(() => _errorMessage = 'Handle cannot contain spaces.');
      return;
    }
    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Display name is required.');
      return;
    }

    final trimmedBlocks = _blockController.trimmedBlocks;
    if (trimmedBlocks.isEmpty) {
      setState(() => _errorMessage = 'Add some content before publishing.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final parsedTags = _tagsController.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    final profile = AuthorProfile(
      uid: user.uid,
      handle: handle,
      displayName: displayName,
      primeBlocks: trimmedBlocks,
      tags: parsedTags,
      hidden: false,
      createdAt: _existingCreatedAt ?? DateTime.now(),
    );

    try {
      await _contentService.saveAuthorProfile(profile);
      if (mounted) {
        showComposerSnack(context, 'Published.');
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
        title: 'Edit prime',
        isSaving: _isSaving,
        onPublish: _save,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorBanner(message: _errorMessage),
          _buildIdentitySection(),
          Divider(height: 1, color: kBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BlockComposer(
              controller: _blockController,
              firstBlockHint: "What's on your prime?",
            ),
          ),
          _buildTagsSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Identity ──────────────────────────────────────────────────────────────

  Widget _buildIdentitySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: kSurface,
            child: Icon(Icons.person, color: kTextSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                XTextField(
                  controller: _nameController,
                  hint: 'Display name',
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      '@',
                      style: TextStyle(color: kTextSecondary, fontSize: 14),
                    ),
                    Expanded(
                      child: XTextField(
                        controller: _handleController,
                        hint: 'handle',
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tags ──────────────────────────────────────────────────────────────────

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: kBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: const [
              Icon(Icons.tag, size: 16, color: kTextSecondary),
              SizedBox(width: 6),
              Text(
                'Tags',
                style: TextStyle(
                  color: kTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: XTextField(
            controller: _tagsController,
            hint: 'poetry, sci-fi, photography…',
            style: const TextStyle(color: kTextPrimary, fontSize: 15),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            'Comma-separated. Helps readers discover your prime.',
            style: const TextStyle(color: kTextSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
