import 'package:cloud_firestore/cloud_firestore.dart';

enum PrimeContentType { text, imageSet }

extension PrimeContentTypeExtension on PrimeContentType {
  String toValueString() {
    switch (this) {
      case PrimeContentType.text:
        return 'text_or_link';
      case PrimeContentType.imageSet:
        return 'image_set';
    }
  }

  static PrimeContentType fromString(String? value) {
    if (value == 'image_set') {
      return PrimeContentType.imageSet;
    }
    return PrimeContentType.text;
  }
}

/// A single image within a prime image set, paired with its required
/// display name (REQ-FUNC-003: "up to 4 images each with an associated name").
class PrimeImage {
  final String url;
  final String name;

  const PrimeImage({required this.url, this.name = ''});

  factory PrimeImage.fromMap(Map<String, dynamic> map) {
    return PrimeImage(
      url: map['url'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'url': url, 'name': name};

  PrimeImage copyWith({String? url, String? name}) {
    return PrimeImage(url: url ?? this.url, name: name ?? this.name);
  }
}

class AuthorProfile {
  final String uid;
  final String handle;
  final String displayName;
  final PrimeContentType primeContentType;
  final String? textPayload; // Used when primeContentType == text
  final List<PrimeImage> images; // Used when primeContentType == imageSet (Max 4)
  final List<String> tags; // Normalized strings
  final bool hidden;
  final DateTime? createdAt;

  AuthorProfile({
    required this.uid,
    required this.handle,
    required this.displayName,
    required this.primeContentType,
    this.textPayload,
    this.images = const [],
    this.tags = const [],
    this.hidden = false,
    this.createdAt,
  });

  /// Factory constructor to map from Firestore document snapshot
  factory AuthorProfile.fromMap(String uid, Map<String, dynamic> map) {
    // Backward compatible with the legacy flat `image_urls` field (no names)
    // in case any records were written before names were introduced.
    final List<PrimeImage> parsedImages;
    if (map['images'] != null) {
      parsedImages = (map['images'] as List)
          .map((e) => PrimeImage.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      parsedImages = List<String>.from(map['image_urls'] ?? [])
          .map((url) => PrimeImage(url: url))
          .toList();
    }

    return AuthorProfile(
      uid: uid,
      handle: map['handle'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      primeContentType: PrimeContentTypeExtension.fromString(
        map['prime_content_type'] as String?,
      ),
      textPayload: map['text_payload'] as String?,
      images: parsedImages,
      tags: List<String>.from(map['tags'] ?? []),
      hidden: map['hidden'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts the profile model to flat JSON format for Firestore writes
  Map<String, dynamic> toMap() {
    return {
      'handle': handle.toLowerCase().trim(),
      'displayName': displayName.trim(),
      'prime_content_type': primeContentType.toValueString(),
      'text_payload': textPayload,
      'images': images.map((img) => img.toMap()).toList(),
      'tags': tags.map((t) => t.toLowerCase().trim()).toList(),
      'hidden': hidden,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
