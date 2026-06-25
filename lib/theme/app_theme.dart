import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Design Tokens – used across the whole app
// ─────────────────────────────────────────────────────────────

const Color kBg = Color(0xFF000000);
const Color kSurface = Color(0xFF0F0F0F);
const Color kBorder = Color(0xFF2F2F2F);
const Color kTextPrimary = Color(0xFFE7E9EA);
const Color kTextSecondary = Color(0xFF71767B);
const Color kAccent = Color(0xFF1D9BF0); // X blue
const Color kDestructive = Color(0xFFFF4242);
const Color kSuccess = Color(0xFF00BA7C);

// Reusable text styles
const TextStyle kBodyText = TextStyle(
  color: kTextPrimary,
  fontSize: 15,
  height: 1.4,
);
const TextStyle kTitleText = TextStyle(
  color: kTextPrimary,
  fontSize: 17,
  fontWeight: FontWeight.w700,
);
const TextStyle kSubtitleText = TextStyle(color: kTextSecondary, fontSize: 13);

// Common decoration for cards / containers
BoxDecoration kCardDecoration = BoxDecoration(
  color: kSurface,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: kBorder),
);

// AppBar theme – used in every screen
AppBarTheme kAppBarTheme = const AppBarTheme(
  backgroundColor: kBg,
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  titleTextStyle: TextStyle(
    color: kTextPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  ),
  iconTheme: IconThemeData(color: kTextPrimary),
);
