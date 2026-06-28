import 'package:flutter/material.dart';

typedef VoidRefCallback = void Function();

class ActionButtons extends StatelessWidget {
  final bool isLiked;
  final VoidRefCallback onNext;
  final VoidRefCallback onSubscribe;
  final VoidRefCallback onReadLater;
  final ValueChanged<bool> onLikeToggled;

  const ActionButtons({
    super.key,
    required this.isLiked,
    required this.onNext,
    required this.onSubscribe,
    required this.onReadLater,
    required this.onLikeToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Next button (compact)
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.skip_next, color: Colors.white70, size: 20),
            label: const Text('Next', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[700]!),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Read Later button
          OutlinedButton.icon(
            onPressed: onReadLater,
            icon: const Icon(
              Icons.bookmark_outline,
              color: Colors.orangeAccent,
              size: 20,
            ),
            label: const Text('Read Later', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[700]!),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Subscribe button (primary)
          ElevatedButton.icon(
            onPressed: onSubscribe,
            icon: const Icon(Icons.bolt, color: Colors.black, size: 20),
            label: const Text('Subscribe', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Like toggle (icon only)
          IconButton(
            onPressed: () => onLikeToggled(!isLiked),
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.redAccent : Colors.white60,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
