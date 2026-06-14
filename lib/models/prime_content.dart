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

class AuthorProfile {
  final String uid;
  final String handle;
  final String displayName;
  final PrimeContentType primeContentType;
  final String? textPayload; // Used when primeContentType == text
  final List<String>
  imageUrls; // Used when primeContentType == imageSet (Max 4)
  final List<String> tags; // Normalized strings
  final bool hidden;
  final DateTime? createdAt;

  AuthorProfile({
    required this.uid,
    required this.handle,
    required this.displayName,
    required this.primeContentType,
    this.textPayload,
    this.imageUrls = const [],
    this.tags = const [],
    this.hidden = false,
    this.createdAt,
  });

  /// Factory constructor to map from Firestore document snapshot
  factory AuthorProfile.fromMap(String uid, Map<String, dynamic> map) {
    return AuthorProfile(
      uid: uid,
      handle: map['handle'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      primeContentType: PrimeContentTypeExtension.fromString(
        map['prime_content_type'] as String?,
      ),
      textPayload: map['text_payload'] as String?,
      imageUrls: List<String>.from(map['image_urls'] ?? []),
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
      'image_urls': imageUrls,
      'tags': tags.map((t) => t.toLowerCase().trim()).toList(),
      'hidden': hidden,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
