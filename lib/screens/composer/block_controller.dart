import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/services/storage_service.dart';

/// Encapsulates the mutable block list shared by [ComposePostScreen] and
/// [EditPrimeScreen]. Callers must call [dispose] when done.
///
/// [onStateChanged] fires whenever a visual rebuild is needed.
/// [onError] fires when an operation fails (e.g. upload).
class BlockController {
  BlockController({
    List<PrimeBlock>? initialBlocks,
    required this.imageFilePrefix,
    required this.onStateChanged,
    required this.onError,
  }) : _blocks = initialBlocks != null && initialBlocks.isNotEmpty
           ? List.from(initialBlocks)
           : [const TextBlock(text: '')];

  /// 'prime' or 'post' — used to name uploaded files.
  final String imageFilePrefix;
  final VoidCallback onStateChanged;
  final void Function(String message) onError;

  final StorageService _storageService = StorageService();
  final Map<int, TextEditingController> _textControllers = {};

  List<PrimeBlock> _blocks;

  // ── Public read access ────────────────────────────────────────────────────

  List<PrimeBlock> get blocks => _blocks;

  int get imageCount => _blocks.whereType<ImageBlock>().length;

  /// Flushes controller text into [_blocks] and returns a trimmed copy with
  /// blank text blocks removed. Safe to call before saving.
  List<PrimeBlock> get trimmedBlocks {
    for (final entry in _textControllers.entries) {
      final i = entry.key;
      if (i < _blocks.length && _blocks[i] is TextBlock) {
        _blocks[i] = TextBlock(text: entry.value.text);
      }
    }
    return _blocks
        .where((b) => b is ImageBlock || (b as TextBlock).text.isNotEmpty)
        .toList();
  }

  // ── Controller helpers ────────────────────────────────────────────────────

  /// Returns or lazily creates a [TextEditingController] for the block at
  /// [index]. Always call with the current block's text so the initial value
  /// is set correctly on first access.
  TextEditingController controllerFor(int index, String initialText) {
    return _textControllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialText),
    );
  }

  void _flushStaleControllers() {
    final stale = _textControllers.keys
        .where((k) => k >= _blocks.length)
        .toList();
    for (final k in stale) {
      _textControllers[k]?.dispose();
      _textControllers.remove(k);
    }
  }

  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _textControllers.clear();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  void insertTextBlockAt(int index) {
    _blocks.insert(index, const TextBlock(text: ''));
    _flushStaleControllers();
    onStateChanged();
  }

  void removeBlockAt(int index) {
    _blocks.removeAt(index);
    _flushStaleControllers();
    if (_blocks.isEmpty) _blocks.add(const TextBlock(text: ''));
    onStateChanged();
  }

  /// Silently updates the backing block without triggering a rebuild — the
  /// [TextField] controller already owns the visual state.
  void updateTextBlock(int index, String value) {
    _blocks[index] = TextBlock(text: value);
  }

  void renameImageBlock(int index, String name) {
    final block = _blocks[index];
    if (block is ImageBlock) {
      _blocks[index] = block.copyWith(name: name);
      onStateChanged();
    }
  }

  Future<void> pickAndUploadImageAt(int insertAfterIndex) async {
    if (imageCount >= 4) {
      onError('Maximum 4 images allowed.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.substring(picked.name.lastIndexOf('.'))
        : '.jpg';
    final fileName =
        '${imageFilePrefix}_${user.uid}_${DateTime.now().millisecondsSinceEpoch}$ext';

    // Optimistic placeholder
    _blocks.insert(insertAfterIndex + 1, const ImageBlock(url: '', name: ''));
    _flushStaleControllers();
    onStateChanged();

    try {
      final url = await _storageService.uploadPrimeImage(
        authorId: user.uid,
        fileName: fileName,
        bytes: bytes,
      );
      final placeholderIndex = _blocks.indexWhere(
        (b) => b is ImageBlock && (b as ImageBlock).url.isEmpty,
      );
      if (placeholderIndex != -1) {
        _blocks[placeholderIndex] = ImageBlock(
          url: url,
          name: 'Image $imageCount',
        );
        onStateChanged();
      }
    } catch (e) {
      _blocks.removeWhere(
        (b) => b is ImageBlock && (b as ImageBlock).url.isEmpty,
      );
      _flushStaleControllers();
      onStateChanged();
      onError('Upload failed: $e');
    }
  }

  Future<void> removeImageBlock(int index) async {
    final block = _blocks[index] as ImageBlock;
    _blocks.removeAt(index);
    _flushStaleControllers();
    onStateChanged();
    if (block.url.isNotEmpty) {
      await _storageService.deleteImageByUrl(block.url);
    }
  }
}
