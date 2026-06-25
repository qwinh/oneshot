import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/prime_content.dart';
import '../../services/content_service.dart';
import '../../services/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _bg = Color(0xFF000000);
const _surface = Color(0xFF0F0F0F);
const _border = Color(0xFF2F2F2F);
const _textPrimary = Color(0xFFE7E9EA);
const _textSecondary = Color(0xFF71767B);
const _accent = Color(0xFF1D9BF0); // X blue
const _destructive = Color(0xFFFF4242);

// ─────────────────────────────────────────────────────────────────────────────
// EditPrimeScreen
// ─────────────────────────────────────────────────────────────────────────────

class EditPrimeScreen extends StatefulWidget {
  const EditPrimeScreen({super.key});

  @override
  State<EditPrimeScreen> createState() => _EditPrimeScreenState();
}

class _EditPrimeScreenState extends State<EditPrimeScreen> {
  final ContentService _contentService = ContentService();
  final StorageService _storageService = StorageService();

  final TextEditingController _handleController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  /// Ordered list of content blocks — the source of truth for the editor.
  List<PrimeBlock> _blocks = [const TextBlock(text: '')];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  DateTime? _existingCreatedAt;

  // Per-block TextEditingControllers keyed by a stable block index.
  // Rebuilt whenever blocks are added/removed.
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _handleController.dispose();
    _nameController.dispose();
    _tagsController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  int get _imageCount => _blocks.whereType<ImageBlock>().length;

  /// Returns or creates a TextEditingController for block at [index].
  TextEditingController _controllerFor(int index, String initialText) {
    return _textControllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialText),
    );
  }

  void _flushTextControllers() {
    // Rebuild controller map to match current block list length.
    final stale = _textControllers.keys
        .where((k) => k >= _blocks.length)
        .toList();
    for (final k in stale) {
      _textControllers[k]?.dispose();
      _textControllers.remove(k);
    }
  }

  // ── Data load ────────────────────────────────────────────────────────────────

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await _contentService.getProfile(user.uid);
      if (profile != null && mounted) {
        setState(() {
          _handleController.text = profile.handle;
          _nameController.text = profile.displayName;
          _tagsController.text = profile.tags.join(', ');
          _existingCreatedAt = profile.createdAt;
          _blocks = profile.primeBlocks.isNotEmpty
              ? List.from(profile.primeBlocks)
              : [const TextBlock(text: '')];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Could not load profile.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Block mutations ──────────────────────────────────────────────────────────

  void _insertTextBlockAt(int index) {
    setState(() {
      _blocks.insert(index, const TextBlock(text: ''));
      _flushTextControllers();
    });
  }

  void _removeBlockAt(int index) {
    setState(() {
      _blocks.removeAt(index);
      _flushTextControllers();
      if (_blocks.isEmpty) _blocks.add(const TextBlock(text: ''));
    });
  }

  void _updateTextBlock(int index, String value) {
    _blocks[index] = TextBlock(text: value);
    // No setState — controller drives the text field, no visual rebuild needed.
  }

  void _renameImageBlock(int index, String name) {
    final block = _blocks[index];
    if (block is ImageBlock) {
      setState(() => _blocks[index] = block.copyWith(name: name));
    }
  }

  Future<void> _pickAndUploadImageAt(int insertAfterIndex) async {
    if (_imageCount >= 4) {
      _showSnack('Maximum 4 images allowed.', isError: true);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Let the user pick an image from their gallery.
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return; // user cancelled

    final Uint8List bytes = await picked.readAsBytes();
    final String fileName =
        'prime_${user.uid}_${DateTime.now().millisecondsSinceEpoch}'
        '${picked.name.contains('.') ? picked.name.substring(picked.name.lastIndexOf('.')) : '.jpg'}';

    // Optimistically insert a placeholder so the user sees feedback immediately.
    setState(() {
      _blocks.insert(insertAfterIndex + 1, const ImageBlock(url: '', name: ''));
      _flushTextControllers();
    });

    try {
      final url = await _storageService.uploadPrimeImage(
        authorId: user.uid,
        fileName: fileName,
        bytes: bytes,
      );

      final placeholderIndex = _blocks.indexWhere(
        (b) => b is ImageBlock && (b as ImageBlock).url.isEmpty,
      );
      if (placeholderIndex != -1 && mounted) {
        setState(() {
          _blocks[placeholderIndex] = ImageBlock(
            url: url,
            name: 'Image $_imageCount',
          );
        });
      }
    } catch (e) {
      // Remove the placeholder on failure.
      setState(() {
        _blocks.removeWhere(
          (b) => b is ImageBlock && (b as ImageBlock).url.isEmpty,
        );
        _flushTextControllers();
      });
      _showSnack('Upload failed: $e', isError: true);
    }
  }

  void _removeImageBlock(int index) async {
    final block = _blocks[index] as ImageBlock;
    setState(() {
      _blocks.removeAt(index);
      _flushTextControllers();
    });
    if (block.url.isNotEmpty) {
      await _storageService.deleteImageByUrl(block.url);
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

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

    // Flush text block values from controllers into _blocks before save.
    for (final entry in _textControllers.entries) {
      final i = entry.key;
      if (i < _blocks.length && _blocks[i] is TextBlock) {
        _blocks[i] = TextBlock(text: entry.value.text);
      }
    }

    // Strip blank trailing text blocks.
    final trimmedBlocks = _blocks
        .where((b) => b is ImageBlock || (b as TextBlock).text.isNotEmpty)
        .toList();

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
        _showSnack('Published.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Snack ────────────────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: _textPrimary)),
        backgroundColor: isError ? _destructive : _surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _border),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: _textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Edit prime',
        style: TextStyle(
          color: _textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _textPrimary,
              foregroundColor: _bg,
              disabledBackgroundColor: _border,
              shape: StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _bg,
                    ),
                  )
                : const Text('Publish'),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error banner
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _destructive.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _destructive.withOpacity(0.4)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: _destructive, fontSize: 13),
              ),
            ),

          // Identity row
          _buildIdentitySection(),

          Divider(height: 1, color: _border),

          // Composer area (avatar + blocks)
          _buildComposerSection(),

          // Tags
          _buildTagsSection(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Identity ─────────────────────────────────────────────────────────────────

  Widget _buildIdentitySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar placeholder
          CircleAvatar(
            radius: 20,
            backgroundColor: _surface,
            child: const Icon(Icons.person, color: _textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _XTextField(
                  controller: _nameController,
                  hint: 'Display name',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      '@',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                    Expanded(
                      child: _XTextField(
                        controller: _handleController,
                        hint: 'handle',
                        style: const TextStyle(
                          color: _textSecondary,
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

  // ── Composer ─────────────────────────────────────────────────────────────────

  Widget _buildComposerSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left gutter: thin vertical line like X's thread line
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 2,
                height: _blocks.length > 1 ? null : 0,
                // Stretches naturally inside the Column
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < _blocks.length; i++) ...[
                  _buildBlock(i),
                  _buildInsertRow(i),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(int index) {
    final block = _blocks[index];
    if (block is TextBlock) return _buildTextBlock(index, block);
    if (block is ImageBlock) return _buildImageBlock(index, block);
    return const SizedBox.shrink();
  }

  Widget _buildTextBlock(int index, TextBlock block) {
    final controller = _controllerFor(index, block.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: null,
        minLines: 2,
        style: const TextStyle(color: _textPrimary, fontSize: 17, height: 1.4),
        decoration: InputDecoration(
          hintText: index == 0 ? "What's on your prime?" : 'Continue writing…',
          hintStyle: const TextStyle(color: _textSecondary, fontSize: 17),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) => _updateTextBlock(index, v),
      ),
    );
  }

  Widget _buildImageBlock(int index, ImageBlock block) {
    final isUploading = block.url.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image tile
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isUploading)
                    Container(
                      color: _surface,
                      child: const Center(
                        child: CircularProgressIndicator(color: _accent),
                      ),
                    )
                  else
                    Image.network(
                      block.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _surface,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ),
                  // Remove button
                  if (!isUploading)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removeImageBlock(index),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Image name field
          if (!isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _XTextField(
                initialValue: block.name,
                hint: 'Add image name…',
                style: const TextStyle(color: _textSecondary, fontSize: 13),
                onChanged: (v) => _renameImageBlock(index, v),
              ),
            ),
        ],
      ),
    );
  }

  /// Thin action row between blocks: add text or add image.
  Widget _buildInsertRow(int afterIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _InsertChip(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Image',
            disabled: _imageCount >= 4,
            onTap: () => _pickAndUploadImageAt(afterIndex),
          ),
          const SizedBox(width: 8),
          if (afterIndex < _blocks.length - 1 ||
              _blocks[afterIndex] is ImageBlock)
            _InsertChip(
              icon: Icons.text_fields_outlined,
              label: 'Text',
              onTap: () => _insertTextBlockAt(afterIndex + 1),
            ),
        ],
      ),
    );
  }

  // ── Tags ─────────────────────────────────────────────────────────────────────

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: _border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: const [
              Icon(Icons.tag, size: 16, color: _textSecondary),
              SizedBox(width: 6),
              Text(
                'Tags',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _XTextField(
            controller: _tagsController,
            hint: 'poetry, sci-fi, photography…',
            style: const TextStyle(color: _textPrimary, fontSize: 15),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            'Comma-separated. Helps readers discover your prime.',
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared primitives
// ─────────────────────────────────────────────────────────────────────────────

/// Borderless text field matching X's composer aesthetic.
class _XTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String hint;
  final TextStyle style;
  final ValueChanged<String>? onChanged;

  const _XTextField({
    this.controller,
    this.initialValue,
    required this.hint,
    required this.style,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return TextField(
        controller: controller,
        style: style,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: style.copyWith(color: _textSecondary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      );
    }
    return TextFormField(
      initialValue: initialValue,
      style: style,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: _textSecondary),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// Small pill chip used for inline insert actions.
class _InsertChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

  const _InsertChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
