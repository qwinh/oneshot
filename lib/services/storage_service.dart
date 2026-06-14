import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads binary raw image bytes to a dedicated directory for the creator.
  /// Returns the public secure download URL.
  Future<String> uploadPrimeImage({
    required String authorId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Unique storage path structured neatly per author profile
    final String path = 'authors/$authorId/prime/$fileName';
    final Reference ref = _storage.ref().child(path);

    // Upload with standard metadata definition
    final UploadTask uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Deletes a specific file from Firebase Storage
  Future<void> deleteImageByUrl(String url) async {
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // Graceful error fallback for PoC stability
    }
  }
}
