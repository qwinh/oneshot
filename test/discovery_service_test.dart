import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneshot/models/relation.dart';
import 'package:oneshot/services/discovery_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DiscoveryService discoveryService;

  const String kViewerId = 'viewer_1';
  const String kAuthorA = 'author_a';
  const String kAuthorB = 'author_b';

  /// Writes an `authors/{uid}` document with the minimal fields
  /// AuthorProfile.fromMap expects.
  Future<void> seedAuthor({
    required String uid,
    required String handle,
    String displayName = 'Display Name',
    bool hidden = false,
    List<String> tags = const [],
  }) async {
    await fakeFirestore.collection('authors').doc(uid).set({
      'handle': handle,
      'displayName': displayName,
      'prime_content_type': 'text_or_link',
      'text_payload': 'Some prime text',
      'images': [],
      'tags': tags,
      'hidden': hidden,
      'created_at': Timestamp.now(),
    });

    for (final tag in tags) {
      await fakeFirestore
          .collection('tags')
          .doc(tag)
          .collection('authors')
          .doc(uid)
          .set({
            'authorId': uid,
            'handle': handle,
            'displayName': displayName,
            'prime_content_type': 'text_or_link',
            'updated_at': Timestamp.now(),
          });
    }
  }

  /// Writes a `relations/{viewerId}_{authorId}` document directly,
  /// bypassing RelationService, so each test can set up exactly the
  /// relation state it needs to exercise.
  Future<void> seedRelation({
    required String viewerId,
    required String authorId,
    bool discoveryConsumed = false,
    String actionType = 'none',
    bool subscribed = false,
    bool readLater = false,
    bool liked = false,
    Timestamp? consumedAt,
  }) async {
    await fakeFirestore.collection('relations').doc('${viewerId}_$authorId').set({
      'viewerId': viewerId,
      'authorId': authorId,
      'discovery_consumed': discoveryConsumed,
      'pending_card': false,
      'action_type': actionType,
      'subscribed': subscribed,
      'read_later': readLater,
      'liked': liked,
      'consumed_at': consumedAt,
      'updated_at': Timestamp.now(),
    });
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    discoveryService = DiscoveryService(firestore: fakeFirestore);
  });

  group('Tag-Based Discovery Browsing (REQ-FUNC-006)', () {
    test('Returns a creator tagged and not yet consumed by this viewer', () async {
      await seedAuthor(uid: kAuthorA, handle: 'author_a', tags: ['poetry']);

      final results = await discoveryService.browseByTag(
        viewerId: kViewerId,
        tag: 'poetry',
      );

      expect(results.length, 1);
      expect(results.first.uid, kAuthorA);
    });

    test(
      'Excludes a creator once the viewer has consumed their discovery chance',
      () async {
        await seedAuthor(uid: kAuthorA, handle: 'author_a', tags: ['poetry']);
        await seedRelation(
          viewerId: kViewerId,
          authorId: kAuthorA,
          discoveryConsumed: true,
          actionType: 'next',
        );

        final results = await discoveryService.browseByTag(
          viewerId: kViewerId,
          tag: 'poetry',
        );

        expect(results, isEmpty);
      },
    );

    test('Excludes hidden creator profiles from tag browse results', () async {
      await seedAuthor(
        uid: kAuthorA,
        handle: 'author_a',
        tags: ['poetry'],
        hidden: true,
      );

      final results = await discoveryService.browseByTag(
        viewerId: kViewerId,
        tag: 'poetry',
      );

      expect(results, isEmpty);
    });

    test('A creator never appears in their own discovery browse results', () async {
      await seedAuthor(uid: kViewerId, handle: 'self', tags: ['poetry']);

      final results = await discoveryService.browseByTag(
        viewerId: kViewerId,
        tag: 'poetry',
      );

      expect(results, isEmpty);
    });
  });

  group('Derived Feeds (Appendix B)', () {
    test('Read Later Feed includes only creators with read_later = true', () async {
      await seedAuthor(uid: kAuthorA, handle: 'author_a');
      await seedAuthor(uid: kAuthorB, handle: 'author_b');
      await seedRelation(
        viewerId: kViewerId,
        authorId: kAuthorA,
        discoveryConsumed: true,
        actionType: 'read_later',
        readLater: true,
      );
      await seedRelation(
        viewerId: kViewerId,
        authorId: kAuthorB,
        discoveryConsumed: true,
        actionType: 'next',
      );

      final feed = await discoveryService.getReadLaterFeed(kViewerId);

      expect(feed.length, 1);
      expect(feed.first.uid, kAuthorA);
    });

    test('Liked Authors Feed does not require discovery to be consumed (REQ-FUNC-017)', () async {
      await seedAuthor(uid: kAuthorA, handle: 'author_a');
      await seedRelation(
        viewerId: kViewerId,
        authorId: kAuthorA,
        discoveryConsumed: false,
        liked: true,
      );

      final feed = await discoveryService.getLikedAuthorsFeed(kViewerId);

      expect(feed.length, 1);
      expect(feed.first.uid, kAuthorA);
    });

    test(
      'Viewed Authors Feed surfaces action_type and consumed_at per creator (REQ-FUNC-016)',
      () async {
        await seedAuthor(uid: kAuthorA, handle: 'author_a');
        final Timestamp consumedAt = Timestamp.now();
        await seedRelation(
          viewerId: kViewerId,
          authorId: kAuthorA,
          discoveryConsumed: true,
          actionType: 'subscribe',
          subscribed: true,
          consumedAt: consumedAt,
        );

        final feed = await discoveryService.getViewedAuthorsFeed(kViewerId);

        expect(feed.length, 1);
        expect(feed.first.profile.uid, kAuthorA);
        expect(feed.first.actionType, ActionType.subscribe);
        expect(feed.first.consumedAt, isNotNull);
      },
    );
  });

  group('Search (REQ-FUNC-018)', () {
    test('Search returns a creator regardless of consumed relation state', () async {
      await seedAuthor(uid: kAuthorA, handle: 'skipped_creator');
      await seedRelation(
        viewerId: kViewerId,
        authorId: kAuthorA,
        discoveryConsumed: true,
        actionType: 'next',
      );

      final results = await discoveryService.searchAuthors('skipped_creator');

      expect(results.length, 1);
      expect(results.first.uid, kAuthorA);
    });

    test('Search returns nothing for a handle with no match', () async {
      await seedAuthor(uid: kAuthorA, handle: 'someone');

      final results = await discoveryService.searchAuthors('nobody_here');

      expect(results, isEmpty);
    });
  });

  group('Standard Post Feed (REQ-FUNC-021)', () {
    test('getAuthorWorks returns only that author\'s posts, newest first', () async {
      await fakeFirestore.collection('works').add({
        'authorId': kAuthorA,
        'authorName': 'Author A',
        'authorHandle': 'author_a',
        'content': 'First post',
        'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await fakeFirestore.collection('works').add({
        'authorId': kAuthorA,
        'authorName': 'Author A',
        'authorHandle': 'author_a',
        'content': 'Second post',
        'created_at': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });
      await fakeFirestore.collection('works').add({
        'authorId': kAuthorB,
        'authorName': 'Author B',
        'authorHandle': 'author_b',
        'content': 'Someone else\'s post',
        'created_at': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });

      final works = await discoveryService.getAuthorWorks(kAuthorA);

      expect(works.length, 2);
      expect(works.every((w) => w.authorId == kAuthorA), isTrue);
      expect(works.first.content, 'Second post'); // newest first
    });
  });
}
