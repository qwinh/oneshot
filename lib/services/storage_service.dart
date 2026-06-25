// lib/services/storage_service.dart

import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StorageService {
  // 🔑 Get your free API key at https://imgbb.com/
  final String apiKey =
      'd119856c209a4f9d7579caecb90defa1'; // <-- replace with your real key

  Future<String> uploadPrimeImage({
    required String authorId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: fileName),
    );
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final json = jsonDecode(responseBody);
    if (json['success'] == true) {
      return json['data']['url'];
    } else {
      throw Exception('ImgBB upload failed: ${json['error']['message']}');
    }
  }

  // ImgBB has no free deletion API, so we keep this as a no-op
  Future<void> deleteImageByUrl(String url) async {
    // optional: you could ignore or log
    return;
  }
}
