import 'package:flutter/material.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/image_grid.dart';

class PrimeCard extends StatelessWidget {
  final AuthorProfile profile;

  const PrimeCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Author Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
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
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('@${profile.handle}', style: kSubtitleText),
                    ],
                  ),
                ),
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
          ),
          const Divider(height: 1, color: kBorder),

          // Core Prime Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: profile.primeBlocks.every((b) => b is TextBlock)
                ? _buildTextPayload()
                : _buildImageSetGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPayload() {
    return Text(
      profile.primeBlocks.whereType<TextBlock>().map((b) => b.text).join('\n'),
      style: kBodyText,
    );
  }

  Widget _buildImageSetGrid() {
    final imageBlocks = profile.primeBlocks.whereType<ImageBlock>().toList();
    if (imageBlocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Discovery Image Portfolio',
          style: TextStyle(
            color: kTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ImageGrid(
          images: imageBlocks
              .map((b) => PrimeImage(url: b.url, name: b.name))
              .toList(),
        ),
      ],
    );
  }
}
