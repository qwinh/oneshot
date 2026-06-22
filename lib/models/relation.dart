import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the action types a user can choose on discovery completion.
enum ActionType { subscribe, next, readLater, none }

extension ActionTypeExtension on ActionType {
  String toValueString() {
    switch (this) {
      case ActionType.subscribe:
        return 'subscribe';
      case ActionType.next:
        return 'next';
      case ActionType.readLater:
        return 'read_later';
      case ActionType.none:
        return 'none';
    }
  }

  static ActionType fromString(String? value) {
    switch (value) {
      case 'subscribe':
        return ActionType.subscribe;
      case 'next':
        return ActionType.next;
      case 'read_later':
        return ActionType.readLater;
      case 'none':
      default:
        return ActionType.none;
    }
  }
}

/// Logical model matching the `relations/{viewerId_authorId}` Firestore schema.
/// This acts as the structural pivot point for the entire Prime app application state.
class ViewerAuthorRelation {
  final String viewerId;
  final String authorId;
  final bool discoveryConsumed;
  final bool pendingCard;
  final ActionType actionType;
  final bool subscribed;
  final bool readLater;
  final bool liked;
  final DateTime? consumedAt;
  final DateTime? updatedAt;
  final DateTime? profileVisitedAt;

  ViewerAuthorRelation({
    required this.viewerId,
    required this.authorId,
    this.discoveryConsumed = false,
    this.pendingCard = false,
    this.actionType = ActionType.none,
    this.subscribed = false,
    this.readLater = false,
    this.liked = false,
    this.consumedAt,
    this.updatedAt,
    this.profileVisitedAt,
  });

  /// Computes the deterministic Firestore Document ID for this relation row.
  String get documentId => '${viewerId}_$authorId';

  /// Helper to duplicate state with optional updates
  ViewerAuthorRelation copyWith({
    String? viewerId,
    String? authorId,
    bool? discoveryConsumed,
    bool? pendingCard,
    ActionType? actionType,
    bool? subscribed,
    bool? readLater,
    bool? liked,
    DateTime? consumedAt,
    DateTime? updatedAt,
    DateTime? profileVisitedAt,
  }) {
    return ViewerAuthorRelation(
      viewerId: viewerId ?? this.viewerId,
      authorId: authorId ?? this.authorId,
      discoveryConsumed: discoveryConsumed ?? this.discoveryConsumed,
      pendingCard: pendingCard ?? this.pendingCard,
      actionType: actionType ?? this.actionType,
      subscribed: subscribed ?? this.subscribed,
      readLater: readLater ?? this.readLater,
      liked: liked ?? this.liked,
      consumedAt: consumedAt ?? this.consumedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileVisitedAt: profileVisitedAt ?? this.profileVisitedAt,
    );
  }

  /// Converts Firestore map payload back to local strongly typed Model.
  factory ViewerAuthorRelation.fromMap(Map<String, dynamic> map) {
    return ViewerAuthorRelation(
      viewerId: map['viewerId'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      discoveryConsumed: map['discovery_consumed'] as bool? ?? false,
      pendingCard: map['pending_card'] as bool? ?? false,
      actionType: ActionTypeExtension.fromString(map['action_type'] as String?),
      subscribed: map['subscribed'] as bool? ?? false,
      readLater: map['read_later'] as bool? ?? false,
      liked: map['liked'] as bool? ?? false,
      consumedAt: map['consumed_at'] != null
          ? (map['consumed_at'] as Timestamp).toDate()
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] as Timestamp).toDate()
          : null,
      profileVisitedAt: map['profile_visited_at'] != null
          ? (map['profile_visited_at'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts the current logical model state to flat JSON format for Firestore writes.
  Map<String, dynamic> toMap() {
    return {
      'viewerId': viewerId,
      'authorId': authorId,
      'discovery_consumed': discoveryConsumed,
      'pending_card': pendingCard,
      'action_type': actionType.toValueString(),
      'subscribed': subscribed,
      'read_later': readLater,
      'liked': liked,
      'consumed_at': consumedAt != null
          ? Timestamp.fromDate(consumedAt!)
          : null,
      'updated_at': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'profile_visited_at': profileVisitedAt != null
          ? Timestamp.fromDate(profileVisitedAt!)
          : null,
    };
  }
}
