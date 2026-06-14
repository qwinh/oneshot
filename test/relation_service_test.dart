import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneshot/models/relation.dart';
import 'package:oneshot/services/relation_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late RelationService relationService;

  const String kViewerId = 'viewer_123';
  const String kAuthorId = 'author_999';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    relationService = RelationService(firestore: fakeFirestore);
  });

  group('Relation Service - Interruption State Tests (REQ-FUNC-007)', () {
    test('Should establish a new pending card state correctly', () async {
      await relationService.markCardAsPending(
        viewerId: kViewerId,
        authorId: kAuthorId,
      );

      final relation = await relationService.getRelation(kViewerId, kAuthorId);

      expect(relation, isNotNull);
      expect(relation!.pendingCard, isTrue);
      expect(relation.discoveryConsumed, isFalse);
    });

    test(
      'Should locate any existing pending cards for the viewer on startup check',
      () async {
        // Setup mock initial DB state
        await relationService.markCardAsPending(
          viewerId: kViewerId,
          authorId: kAuthorId,
        );

        final interruptedCard = await relationService
            .findInterruptedPendingCard(kViewerId);

        expect(interruptedCard, isNotNull);
        expect(interruptedCard!.authorId, equals(kAuthorId));
        expect(interruptedCard.pendingCard, isTrue);
      },
    );
  });

  group(
    'Relation Service - Core Discovery Gate (REQ-FUNC-005, REQ-FUNC-011)',
    () {
      test(
        'Should transition pending card state into finalized subscribe outcome',
        () async {
          // 1. Enter state: Pending
          await relationService.markCardAsPending(
            viewerId: kViewerId,
            authorId: kAuthorId,
          );

          // 2. Action Trigger: Subscribe
          await relationService.resolvePendingCard(
            viewerId: kViewerId,
            authorId: kAuthorId,
            action: ActionType.subscribe,
          );

          final relation = await relationService.getRelation(
            kViewerId,
            kAuthorId,
          );

          expect(relation!.pendingCard, isFalse);
          expect(relation.discoveryConsumed, isTrue);
          expect(relation.subscribed, isTrue);
          expect(relation.readLater, isFalse);
        },
      );

      test(
        'Should transition pending card state into finalized next outcome',
        () async {
          await relationService.markCardAsPending(
            viewerId: kViewerId,
            authorId: kAuthorId,
          );

          await relationService.resolvePendingCard(
            viewerId: kViewerId,
            authorId: kAuthorId,
            action: ActionType.next,
          );

          final relation = await relationService.getRelation(
            kViewerId,
            kAuthorId,
          );

          expect(relation!.pendingCard, isFalse);
          expect(relation.discoveryConsumed, isTrue);
          expect(relation.subscribed, isFalse);
          expect(relation.readLater, isFalse);
        },
      );

      test(
        'Should prevent repeating or overriding a closed discovery path',
        () async {
          await relationService.markCardAsPending(
            viewerId: kViewerId,
            authorId: kAuthorId,
          );
          await relationService.resolvePendingCard(
            viewerId: kViewerId,
            authorId: kAuthorId,
            action: ActionType.next,
          );

          // Attempting to resolve again must trigger a state validation error
          expect(
            () => relationService.resolvePendingCard(
              viewerId: kViewerId,
              authorId: kAuthorId,
              action: ActionType.subscribe,
            ),
            throwsA(isA<StateError>()),
          );
        },
      );
    },
  );
}
