import 'package:flutter/material.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'block_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BlockComposer
// ─────────────────────────────────────────────────────────────────────────────

/// Renders the full list of editable blocks with insert-row affordances
/// between each one. Delegate block mutations to a [BlockController].
class BlockComposer extends StatelessWidget {
  const BlockComposer({
    super.key,
    required this.controller,
    this.firstBlockHint = "What's on your mind?",
  });

  final BlockController controller;

  /// Placeholder text for the very first text block.
  final String firstBlockHint;

  @override
  Widget build(BuildContext context) {
    final blocks = controller.blocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          _buildBlock(i, blocks[i]),
          _BlockInsertRow(
            afterIndex: i,
            blocks: blocks,
            controller: controller,
          ),
        ],
      ],
    );
  }

  Widget _buildBlock(int index, PrimeBlock block) {
    if (block is TextBlock) {
      return ComposerTextBlock(
        index: index,
        block: block,
        controller: controller,
        hint: index == 0 ? firstBlockHint : 'Continue writing…',
      );
    }
    if (block is ImageBlock) {
      return ComposerImageBlock(
        index: index,
        block: block,
        controller: controller,
      );
    }
    if (block is PendingImageBlock) {
      return ComposerPendingImageBlock(
        index: index,
        block: block,
        controller: controller,
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ComposerTextBlock
// ─────────────────────────────────────────────────────────────────────────────

class ComposerTextBlock extends StatelessWidget {
  const ComposerTextBlock({
    super.key,
    required this.index,
    required this.block,
    required this.controller,
    required this.hint,
  });

  final int index;
  final TextBlock block;
  final BlockController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textController = controller.controllerFor(index, block.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: textController,
        maxLines: null,
        minLines: 2,
        style: const TextStyle(color: kTextPrimary, fontSize: 17, height: 1.4),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextSecondary, fontSize: 17),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) => controller.updateTextBlock(index, v),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ComposerImageBlock
// ─────────────────────────────────────────────────────────────────────────────

class ComposerImageBlock extends StatelessWidget {
  const ComposerImageBlock({
    super.key,
    required this.index,
    required this.block,
    required this.controller,
  });

  final int index;
  final ImageBlock block;
  final BlockController controller;

  @override
  Widget build(BuildContext context) {
    final isUploading = block.url.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                if (isUploading)
                  Container(
                    constraints: const BoxConstraints(minHeight: 220),
                    color: kSurface,
                    child: const Center(
                      child: CircularProgressIndicator(color: kAccent),
                    ),
                  )
                else
                  Image.network(
                    block.url,
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => Container(
                      height: 220,
                      color: kSurface,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: kTextSecondary,
                        ),
                      ),
                    ),
                  ),
                if (!isUploading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => controller.removeImageBlock(index),
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
          if (!isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: XTextField(
                initialValue: block.name,
                hint: 'Add image name…',
                style: const TextStyle(color: kTextSecondary, fontSize: 13),
                onChanged: (v) => controller.renameImageBlock(index, v),
              ),
            ),
        ],
      ),
    );
  }
}

class ComposerPendingImageBlock extends StatelessWidget {
  const ComposerPendingImageBlock({
    super.key,
    required this.index,
    required this.block,
    required this.controller,
  });

  final int index;
  final PendingImageBlock block;
  final BlockController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.memory(
                  block.bytes,
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => controller.removeImageBlock(index),
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
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: XTextField(
              initialValue: block.name,
              hint: 'Add image name…',
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
              onChanged: (v) => controller.renameImageBlock(index, v),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlockInsertRow  (private — used only by BlockComposer)
// ─────────────────────────────────────────────────────────────────────────────

class _BlockInsertRow extends StatelessWidget {
  const _BlockInsertRow({
    required this.afterIndex,
    required this.blocks,
    required this.controller,
  });

  final int afterIndex;
  final List<PrimeBlock> blocks;
  final BlockController controller;

  @override
  Widget build(BuildContext context) {
    final showTextChip =
        afterIndex < blocks.length - 1 || blocks[afterIndex] is ImageBlock;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          InsertChip(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Image',
            disabled: controller.imageCount >= 4,
            onTap: () => controller.pickImageAt(afterIndex),
          ),
          const SizedBox(width: 8),
          if (showTextChip)
            InsertChip(
              icon: Icons.text_fields_outlined,
              label: 'Text',
              onTap: () => controller.insertTextBlockAt(afterIndex + 1),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InsertChip
// ─────────────────────────────────────────────────────────────────────────────

/// Small pill-shaped button used in composer insert rows.
class InsertChip extends StatelessWidget {
  const InsertChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

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

// ─────────────────────────────────────────────────────────────────────────────
// XTextField
// ─────────────────────────────────────────────────────────────────────────────

/// Borderless text field matching the app's composer aesthetic.
/// Accepts either a [controller] (stateful) or an [initialValue] (uncontrolled).
class XTextField extends StatelessWidget {
  const XTextField({
    super.key,
    this.controller,
    this.initialValue,
    required this.hint,
    required this.style,
    this.onChanged,
  }) : assert(
         controller == null || initialValue == null,
         'Provide controller OR initialValue, not both.',
       );

  final TextEditingController? controller;
  final String? initialValue;
  final String hint;
  final TextStyle style;
  final ValueChanged<String>? onChanged;

  InputDecoration get _decoration => InputDecoration(
    hintText: hint,
    hintStyle: style.copyWith(color: kTextSecondary),
    border: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return TextField(
        controller: controller,
        style: style,
        onChanged: onChanged,
        decoration: _decoration,
      );
    }
    return TextFormField(
      initialValue: initialValue,
      style: style,
      onChanged: onChanged,
      decoration: _decoration,
    );
  }
}
