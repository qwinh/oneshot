import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final bool isLiked;
  final VoidRefCallback onNext;
  final VoidRefCallback onSubscribe;
  final VoidRefCallback onReadLater;
  final ValueChanged<bool> onLikeToggled;
  final VoidRefCallback onViewProfile;

  const ActionButtons({
    super.key,
    required this.isLiked,
    required this.onNext,
    required this.onSubscribe,
    required this.onReadLater,
    required this.onLikeToggled,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Consuming Actions Row
          Row(
            children: [
              // Next Action
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.skip_next, color: Colors.white70),
                  label: const Text('Next'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Read Later Action
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReadLater,
                  icon: const Icon(
                    Icons.bookmark_outline,
                    color: Colors.orangeAccent,
                  ),
                  label: const Text('Read Later'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Subscribe Conversion Action
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSubscribe,
                  icon: const Icon(Icons.bolt, color: Colors.black),
                  label: const Text('Subscribe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          // Ancillary Actions Row (Does NOT consume discovery status)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // View Profile Trigger
              TextButton.icon(
                onPressed: onViewProfile,
                icon: const Icon(
                  Icons.person_search_outlined,
                  color: Colors.white70,
                ),
                label: const Text(
                  'View Profile',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              // Like Interactive Switch
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
        ],
      ),
    );
  }
}

typedef VoidRefCallback = void Function();
