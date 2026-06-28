import 'package:flutter/material.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/image_viewer.dart';

class PrimeCard extends StatelessWidget {
  final AuthorProfile profile;
  final void Function(String authorId)?
  onTapAuthor; // <-- new optional callback

  const PrimeCard({super.key, required this.profile, this.onTapAuthor});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author header – now with tappable name
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kBorder,
                  child: Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAuthorName(),
                      const SizedBox(height: 2),
                      Text('@${profile.handle}', style: kSubtitleText),
                    ],
                  ),
                ),
                // PRIME badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'PRIME',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Blocks
            ...profile.primeBlocks.map((block) => _buildBlock(context, block)),
            // Tags
            if (profile.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: profile.tags
                    .map(
                      (tag) => Text(
                        '#$tag',
                        style: kSubtitleText.copyWith(
                          color: kAccent,
                          fontSize: 13,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorName() {
    final child = Text(
      profile.displayName,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: kTextPrimary,
        decoration: onTapAuthor != null ? TextDecoration.underline : null,
      ),
    );
    if (onTapAuthor != null) {
      return GestureDetector(
        onTap: () => onTapAuthor!(profile.uid),
        child: child,
      );
    }
    return child;
  }

  Widget _buildBlock(BuildContext context, PrimeBlock block) {
    if (block is TextBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(block.text, style: kBodyText),
      );
    } else if (block is ImageBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => _showFullScreenImage(context, block.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              block.url,
              fit: BoxFit.contain,
              width: double.infinity,
              height: 200,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: kSurface,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: kTextSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    FullScreenImageViewer.show(context, imageUrl);
  }
}
