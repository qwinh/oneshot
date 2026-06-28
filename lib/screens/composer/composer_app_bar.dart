import 'package:flutter/material.dart';
import 'package:oneshot/theme/app_theme.dart';

/// Standard app bar used by composer screens (compose post, edit prime).
/// Shows a close button on the left, a [title], and a publishing [FilledButton]
/// on the right that switches to a spinner while [isSaving] is true.
class ComposerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ComposerAppBar({
    super.key,
    required this.title,
    required this.isSaving,
    required this.onPublish,
    this.publishLabel = 'Publish',
  });

  final String title;
  final bool isSaving;
  final VoidCallback? onPublish;
  final String publishLabel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1); // +1 for the divider

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: kTextPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: kTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: FilledButton(
            onPressed: isSaving ? null : onPublish,
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
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kBg,
                    ),
                  )
                : Text(publishLabel),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kBorder),
      ),
    );
  }
}
