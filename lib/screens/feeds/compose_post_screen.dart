import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/services/discovery_service.dart';
import 'package:oneshot/services/storage_service.dart';
import 'package:oneshot/theme/app_theme.dart';

class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key});

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final StorageService _storageService = StorageService();

  List<PrimeBlock> _blocks = [const TextBlock(text: '')];
  bool _isSaving = false;
  String? _errorMessage;

  // Per-block TextEditingControllers for text blocks only
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void dispose() {
    for (final c in _textControllers.values) c.dispose();
    super.dispose();
  }

  int get _imageCount => _blocks.whereType<ImageBlock>().length;

  TextEditingController _controllerFor(int index, String initialText) {
    return _textControllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialText),
    );
  }

  void _flushTextControllers() {
    final stale = _textControllers.keys
        .where((k) => k >= _blocks.length)
        .toList();
    for (final k in stale) {
      _textControllers[k]?.dispose();
      _textControllers.remove(k);
    }
  }

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
  }

  void _renameImageBlock(int index, String name) {
    final block = _blocks[index];
    if (block is ImageBlock) {
      setState(() => _blocks[index] = block.copyWith(name: name));
    }
  }

  Future<void> _simulateImageUploadAt(int insertAfterIndex) async {
    if (_imageCount >= 4) {
      _showSnack('Maximum 4 images allowed.', isError: true);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _blocks.insert(insertAfterIndex + 1, const ImageBlock(url: '', name: ''));
      _flushTextControllers();
    });

    try {
      // Minimal 1x1 PNG
      final Uint8List bytes = Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        0,
        0,
        13,
        73,
        72,
        68,
        82,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        31,
        21,
        204,
        137,
        0,
        0,
        0,
        13,
        73,
        68,
        65,
        84,
        120,
        156,
        99,
        96,
        0,
        1,
        0,
        0,
        5,
        0,
        1,
        13,
        10,
        45,
        180,
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130,
      ]);
      final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.png';
      final url = await _storageService.uploadPrimeImage(
        authorId: user.uid,
        fileName: fileName,
        bytes: bytes,
      );

      final realIndex = _blocks.indexWhere(
        (b) => b is ImageBlock && (b as ImageBlock).url.isEmpty,
      );
      if (realIndex != -1 && mounted) {
        setState(() {
          _blocks[realIndex] = ImageBlock(
            url: url,
            name: 'Image ${_imageCount}',
          );
        });
      }
    } catch (e) {
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

  Future<void> _publish() async {
    // Flush text controllers into blocks
    for (final entry in _textControllers.entries) {
      final i = entry.key;
      if (i < _blocks.length && _blocks[i] is TextBlock) {
        _blocks[i] = TextBlock(text: entry.value.text);
      }
    }

    // Strip empty trailing text blocks
    final trimmedBlocks = _blocks
        .where((b) => b is ImageBlock || (b as TextBlock).text.isNotEmpty)
        .toList();

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
        _showSnack('Post published!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: kTextPrimary)),
        backgroundColor: isError ? kDestructive : kSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kBorder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'New Post',
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: FilledButton(
              onPressed: _isSaving ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: kTextPrimary,
                foregroundColor: kBg,
                disabledBackgroundColor: kBorder,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        color: kBg,
                      ),
                    )
                  : const Text('Publish'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kDestructive.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kDestructive.withOpacity(0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: kDestructive, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 12),
              ..._buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildComposer() {
    final children = <Widget>[];
    for (int i = 0; i < _blocks.length; i++) {
      children.add(_buildBlock(i));
      children.add(_buildInsertRow(i));
    }
    return children;
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
        style: kBodyText,
        decoration: InputDecoration(
          hintText: index == 0 ? "What's on your mind?" : 'Continue writing…',
          hintStyle: kSubtitleText.copyWith(fontSize: 17),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isUploading)
                    Container(
                      color: kSurface,
                      child: const Center(
                        child: CircularProgressIndicator(color: kAccent),
                      ),
                    )
                  else
                    Image.network(
                      block.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: kSurface,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: kTextSecondary,
                        ),
                      ),
                    ),
                  if (!isUploading)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removeImageBlock(index),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
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
          if (!isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextFormField(
                initialValue: block.name, // ✅ now works with TextFormField
                style: kSubtitleText.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add image name…',
                  hintStyle: kSubtitleText,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => _renameImageBlock(index, v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsertRow(int afterIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _InsertChip(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Image',
            disabled: _imageCount >= 4,
            onTap: () => _simulateImageUploadAt(afterIndex),
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
}

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
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: kTextSecondary,
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
