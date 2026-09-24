import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'trust_repository.dart' show RepositoryException;

/// Stores death certificates and member photos on Cloudinary (IMPLEMENTATION_PLAN
/// Phase 13).
/// The database keeps only the returned `https://res.cloudinary.com/...` URL.
abstract class CertificateUploader {
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

  /// Cloudinary's free plan limit per image or PDF.
  static const maxBytes = 10 * 1024 * 1024;

  Future<String> upload(Uint8List bytes, String fileName);

  /// Refuses files Cloudinary or the office could not use.
  static void check(int length, String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw const RepositoryException('Choose a photo (JPG, PNG) or a PDF.');
    }
    if (length > maxBytes) {
      throw const RepositoryException(
        'The file is larger than 10 MB. Take a smaller photo.',
      );
    }
  }
}

/// Unsigned upload with a preset that limits folder, formats and size.
class CloudinaryUploader implements CertificateUploader {
  CloudinaryUploader({
    required this.cloudName,
    required this.uploadPreset,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String cloudName;
  final String uploadPreset;
  final http.Client _client;

  @override
  Future<String> upload(Uint8List bytes, String fileName) async {
    CertificateUploader.check(bytes.length, fileName);
    final request = http.MultipartRequest(
      'POST',
      Uri.https('api.cloudinary.com', '/v1_1/$cloudName/auto/upload'),
    )
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw const RepositoryException(
        'Could not upload the file. Check the internet and try again.',
      );
    }
    final body = _decode(response.body);
    final url = body['secure_url'];
    if (response.statusCode != 200 || url is! String) {
      final error = body['error'];
      debugPrint('Cloudinary upload failed (${response.statusCode}): $error');
      throw const RepositoryException(
        'Could not upload the file. Try again, or send it to the office.',
      );
    }
    return url;
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }
}

/// Demo mode and tests: pretends to upload.
class FakeCertificateUploader implements CertificateUploader {
  @override
  Future<String> upload(Uint8List bytes, String fileName) async {
    CertificateUploader.check(bytes.length, fileName);
    return 'https://res.cloudinary.com/demo/image/upload/${Uri.encodeComponent(fileName)}';
  }
}

/// Live build without Cloudinary settings: says so instead of failing oddly.
class UnconfiguredCertificateUploader implements CertificateUploader {
  @override
  Future<String> upload(Uint8List bytes, String fileName) async {
    throw const RepositoryException(
      'File upload is not set up yet. Send it to the office.',
    );
  }
}
