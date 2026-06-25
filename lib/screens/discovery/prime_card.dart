import 'package:flutter/material.dart';
import '../../models/prime_content.dart';
import '../../widgets/image_grid.dart';

class PrimeCard extends StatelessWidget {
  final AuthorProfile profile;

  const PrimeCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Author Header block
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
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
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${profile.handle}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Premium indicator
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
          const Divider(height: 1, color: Colors.white10),

          // Core Prime Content (REQ-FUNC-003)
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
      style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
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
            color: Colors.grey,
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
