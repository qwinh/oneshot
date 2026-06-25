import 'package:flutter/material.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/models/work.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'package:oneshot/widgets/image_grid.dart';

class PostCard extends StatelessWidget {
  final Work work;

  const PostCard({super.key, required this.work});

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  work.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kTextPrimary,
                  ),
                ),
                Text(
                  '${work.createdAt.hour}:${work.createdAt.minute.toString().padLeft(2, '0')}',
                  style: kSubtitleText.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('@${work.authorHandle}', style: kSubtitleText),
            const SizedBox(height: 12),
            // Render blocks
            ...work.blocks.map((block) => _buildBlock(block)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(PrimeBlock block) {
    if (block is TextBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(block.text, style: kBodyText),
      );
    } else if (block is ImageBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            block.url,
            fit: BoxFit.cover,
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
      );
    }
    return const SizedBox.shrink();
  }
}
