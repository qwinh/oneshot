import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/services/content_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ContentService contentService;

  AuthorProfile buildProfile({
    required String uid,
    required String handle,
    String displayName = 'Display Name',
    List<String> tags = const [],
  }) {
    return AuthorProfile(
      uid: uid,
      handle: handle,
      displayName: displayName,
      primeBlocks: const [TextBlock(text: 'Hello world')],
      tags: tags,
      hidden: false,
      createdAt: DateTime(2026, 6, 30),
    );
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    contentService = ContentService(firestore: fakeFirestore);
  });

  group('ContentService handle rules', () {
    test('reserves a unique handle when saving a profile', () async {
      await contentService.saveAuthorProfile(
        buildProfile(uid: 'author_1', handle: 'UniqueName'),
      );

      final handleDoc = await fakeFirestore
          .collection('handles')
          .doc('uniquename')
          .get();

      expect(handleDoc.exists, isTrue);
      expect(handleDoc.data()?['uid'], 'author_1');
    });

    test('rejects a handle already claimed by another user', () async {
      await fakeFirestore.collection('handles').doc('takenname').set({
        'uid': 'author_1',
        'updated_at': Timestamp.now(),
      });

      expect(
        () => contentService.saveAuthorProfile(
          buildProfile(uid: 'author_2', handle: 'TakenName'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'That handle is already taken.',
          ),
        ),
      );
    });

    test('reports an existing handle before save', () async {
      await fakeFirestore.collection('handles').doc('takenname').set({
        'uid': 'author_1',
        'updated_at': Timestamp.now(),
      });

      expect(
        await contentService.isHandleTaken('TakenName'),
        isTrue,
      );
      expect(
        await contentService.isHandleTaken(
          'TakenName',
          excludingUid: 'author_1',
        ),
        isFalse,
      );
    });

    test('rejects changing an existing handle', () async {
      await fakeFirestore.collection('authors').doc('author_1').set({
        'handle': 'firsthandle',
        'displayName': 'Display Name',
        'prime_blocks': [
          {'type': 'text', 'text': 'Hello world'},
        ],
        'tags': ['poetry'],
        'hidden': false,
        'created_at': Timestamp.now(),
      });

      expect(
        () => contentService.saveAuthorProfile(
          buildProfile(
            uid: 'author_1',
            handle: 'secondhandle',
            tags: const ['poetry'],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Handle is permanent and cannot be changed.',
          ),
        ),
      );
    });
  });
}
