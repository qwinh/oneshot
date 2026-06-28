import 'package:flutter/material.dart';
import 'package:oneshot/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ErrorBanner
// ─────────────────────────────────────────────────────────────────────────────

/// Inline error container shown at the top of a composer body.
/// Returns [SizedBox.shrink] when [message] is null.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kDestructive.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kDestructive.withOpacity(0.4)),
      ),
      child: Text(
        message!,
        style: const TextStyle(color: kDestructive, fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// showComposerSnack
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a floating [SnackBar] styled for composer screens.
void showComposerSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: kTextPrimary)),
      backgroundColor: isError ? kDestructive : kSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorder),
      ),
    ),
  );
}
