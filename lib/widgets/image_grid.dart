import 'package:flutter/material.dart';
import '../models/prime_content.dart';

/// Read-only grid for displaying a prime image set (up to 4 images),
/// each labeled with its associated name per REQ-FUNC-003.
///
/// Used by PrimeCard (discovery card / search preview / profile screen)
/// wherever a published image-set needs to be rendered for a viewer.
/// For the *editable* upload flow with add/remove/rename controls, see
/// EditPrimeScreen, which manages its own inline editing UI.
class ImageGrid extends StatelessWidget {
  final List<PrimeImage> images;
  final String emptyLabel;

  const ImageGrid({
    super.key,
    required this.images,
    this.emptyLabel = 'No images have been published yet.',
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          emptyLabel,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final int count = images.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: count == 1 ? 1.4 : 0.85,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final image = images[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[850],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white24,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (image.name.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                image.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
