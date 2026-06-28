// lib/services/storage_service.dart

import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minio/minio.dart';

class StorageService {
  // Read from environment
  final String _accountId = dotenv.env['R2_ACCOUNT_ID'] ?? '';
  final String _accessKeyId = dotenv.env['R2_ACCESS_KEY'] ?? '';
  final String _secretAccessKey = dotenv.env['R2_SECRET_KEY'] ?? '';
  final String _bucketName = dotenv.env['R2_BUCKET_NAME'] ?? '';
  final String _publicBaseUrl = dotenv.env['R2_PUBLIC_URL'] ?? '';

  // Validate that all keys exist
  StorageService() {
    if (_accountId.isEmpty ||
        _accessKeyId.isEmpty ||
        _secretAccessKey.isEmpty ||
        _bucketName.isEmpty ||
        _publicBaseUrl.isEmpty) {
      throw Exception('Missing Cloudflare R2 credentials in .env file');
    }
  }

  late final Minio _minio = Minio(
    endPoint: '$_accountId.r2.cloudflarestorage.com',
    accessKey: _accessKeyId,
    secretKey: _secretAccessKey,
    region: 'auto',
    useSSL: true,
  );

  Future<String> uploadPrimeImage({
    required String authorId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final String objectName = 'authors/$authorId/prime/$fileName';
      await _minio.putObject(
        _bucketName,
        objectName,
        Stream.fromIterable([bytes]),
      );
      final String publicUrl = '$_publicBaseUrl/$objectName';
      print('✅ Uploaded to R2: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Upload failed: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> deleteImageByUrl(String url) async {
    try {
      final String objectName = url.replaceFirst('$_publicBaseUrl/', '');
      await _minio.removeObject(_bucketName, objectName);
      print('✅ Deleted: $objectName');
    } catch (e) {
      print('❌ Delete failed: $e');
    }
  }
}
