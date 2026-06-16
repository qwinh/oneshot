import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents regular content updates published by creators post-discovery.
/// Subscribed viewers can consume these in their Subscribe Feed (REQ-FUNC-008, REQ-FUNC-014).
class Work {
  final String id;
  final String authorId;
  final String authorName;
  final String authorHandle;
  final String content;
  final DateTime createdAt;

  Work({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorHandle,
    required this.content,
    required this.createdAt,
  });

  factory Work.fromMap(String id, Map<String, dynamic> map) {
    return Work(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorHandle: map['authorHandle'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'content': content,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
