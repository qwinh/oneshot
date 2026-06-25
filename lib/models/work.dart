import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneshot/models/prime_content.dart';

/// Represents a regular content update published by a creator.
/// Supports the same rich block structure as Prime content.
class Work {
  final String id;
  final String authorId;
  final String authorName;
  final String authorHandle;
  final List<PrimeBlock> blocks; // new: rich content
  final String content; // legacy fallback (may be empty)
  final DateTime createdAt;

  Work({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorHandle,
    this.blocks = const [],
    this.content = '',
    required this.createdAt,
  });

  factory Work.fromMap(String id, Map<String, dynamic> map) {
    List<PrimeBlock> parsedBlocks = [];
    if (map['blocks'] != null) {
      parsedBlocks = (map['blocks'] as List)
          .map((e) => PrimeBlock.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      // Legacy: read content as a single text block
      final text = map['content'] as String? ?? '';
      if (text.isNotEmpty) {
        parsedBlocks = [TextBlock(text: text)];
      }
    }

    return Work(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorHandle: map['authorHandle'] as String? ?? '',
      blocks: parsedBlocks,
      content: map['content'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    // Store blocks as the primary source.
    // Also store a legacy 'content' field (concatenated text) for backward compatibility.
    final textBlocks = blocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .join('\n');
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'content': textBlocks.isNotEmpty ? textBlocks : content,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
