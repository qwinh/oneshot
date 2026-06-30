import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

// ─────────────────────────────────────────────
// Block model
// ─────────────────────────────────────────────

/// A single unit in a prime post — either a run of text or an image.
/// Stored as an ordered list (`prime_blocks`) in the Firestore `authors` doc.
sealed class PrimeBlock {
  const PrimeBlock();

  Map<String, dynamic> toMap();

  factory PrimeBlock.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String? ?? 'text';
    if (type == 'image') {
      return ImageBlock(
        url: map['url'] as String? ?? '',
        name: map['name'] as String? ?? '',
      );
    }
    return TextBlock(text: map['text'] as String? ?? '');
  }
}

class PendingImageBlock extends PrimeBlock {
  final Uint8List bytes;
  final String fileName;
  final String name;

  const PendingImageBlock({
    required this.bytes,
    required this.fileName,
    this.name = '',
  });

  @override
  Map<String, dynamic> toMap() {
    throw StateError('PendingImageBlock cannot be serialized.');
  }

  PendingImageBlock copyWith({
    Uint8List? bytes,
    String? fileName,
    String? name,
  }) => PendingImageBlock(
    bytes: bytes ?? this.bytes,
    fileName: fileName ?? this.fileName,
    name: name ?? this.name,
  );
}

class TextBlock extends PrimeBlock {
  final String text;
  const TextBlock({required this.text});

  @override
  Map<String, dynamic> toMap() => {'type': 'text', 'text': text};

  TextBlock copyWith({String? text}) => TextBlock(text: text ?? this.text);
}

class ImageBlock extends PrimeBlock {
  final String url;
  final String name;
  const ImageBlock({required this.url, this.name = ''});

  @override
  Map<String, dynamic> toMap() => {'type': 'image', 'url': url, 'name': name};

  ImageBlock copyWith({String? url, String? name}) =>
      ImageBlock(url: url ?? this.url, name: name ?? this.name);
}

// ─────────────────────────────────────────────
// Legacy shim — kept only for fromMap migration
// ─────────────────────────────────────────────

/// Still used by StorageService path helpers and legacy fromMap reads.
class PrimeImage {
  final String url;
  final String name;
  const PrimeImage({required this.url, this.name = ''});

  factory PrimeImage.fromMap(Map<String, dynamic> map) => PrimeImage(
    url: map['url'] as String? ?? '',
    name: map['name'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {'url': url, 'name': name};
  PrimeImage copyWith({String? url, String? name}) =>
      PrimeImage(url: url ?? this.url, name: name ?? this.name);
}

// ─────────────────────────────────────────────
// AuthorProfile
// ─────────────────────────────────────────────

class AuthorProfile {
  final String uid;
  final String handle;
  final String displayName;

  /// The unified, ordered content blocks for this author's prime post.
  final List<PrimeBlock> primeBlocks;

  final List<String> tags;
  final bool hidden;
  final DateTime? createdAt;

  AuthorProfile({
    required this.uid,
    required this.handle,
    required this.displayName,
    this.primeBlocks = const [],
    this.tags = const [],
    this.hidden = false,
    this.createdAt,
  });

  /// Number of image blocks in this profile (cap: 4).
  int get imageCount => primeBlocks.whereType<ImageBlock>().length;

  /// Returns a string describing the content mix: 'text', 'image', or 'mixed'.
  /// Used when updating the inverted tag index.
  String get contentTypeString {
    bool hasText = primeBlocks.any((b) => b is TextBlock);
    bool hasImage = primeBlocks.any((b) => b is ImageBlock);
    if (hasText && hasImage) return 'mixed';
    if (hasImage) return 'image';
    return 'text';
  }

  // ── Firestore read ──────────────────────────────────────────────────────────

  factory AuthorProfile.fromMap(String uid, Map<String, dynamic> map) {
    List<PrimeBlock> blocks;

    if (map['prime_blocks'] != null) {
      // New schema
      blocks = (map['prime_blocks'] as List)
          .map((e) => PrimeBlock.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      // Migrate legacy schema → blocks on read (no write required)
      blocks = [];
      final textPayload = map['text_payload'] as String?;
      if (textPayload != null && textPayload.isNotEmpty) {
        blocks.add(TextBlock(text: textPayload));
      }
      // Legacy image_urls (pre-name)
      if (map['images'] != null) {
        for (final e in (map['images'] as List)) {
          final img = PrimeImage.fromMap(Map<String, dynamic>.from(e as Map));
          blocks.add(ImageBlock(url: img.url, name: img.name));
        }
      } else if (map['image_urls'] != null) {
        for (final url in List<String>.from(map['image_urls'] ?? [])) {
          blocks.add(ImageBlock(url: url));
        }
      }
    }

    return AuthorProfile(
      uid: uid,
      handle: map['handle'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      primeBlocks: blocks,
      tags: List<String>.from(map['tags'] ?? []),
      hidden: map['hidden'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  // ── Firestore write ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'handle': handle.toLowerCase().trim(),
      'displayName': displayName.trim(),
      'prime_blocks': primeBlocks.map((b) => b.toMap()).toList(),
      'tags': tags.map((t) => t.toLowerCase().trim()).toList(),
      'hidden': hidden,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
