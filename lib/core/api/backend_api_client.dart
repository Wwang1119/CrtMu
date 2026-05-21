import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/artwork/models/artwork_models.dart';

class BackendApiClient {
  final String baseUrl;
  final http.Client _http;
  final bool _ownsClient;
  final Duration textTimeout;
  final Duration uploadTimeout;
  final Duration analyzeTimeout;
  final Duration referenceGenerationTimeout;

  BackendApiClient({
    required this.baseUrl,
    http.Client? client,
    this.textTimeout = const Duration(seconds: 20),
    this.uploadTimeout = const Duration(seconds: 20),
    this.analyzeTimeout = const Duration(seconds: 60),
    this.referenceGenerationTimeout = const Duration(seconds: 90),
  }) : _http = client ?? http.Client(),
       _ownsClient = client == null;

  void close() {
    if (_ownsClient) {
      _http.close();
    }
  }

  Future<String> sendText(String text) async {
    final url = Uri.parse('$baseUrl/chat');
    final payload = <String, dynamic>{'message': text};

    debugPrint('[CrtMu][Backend] POST $url');
    debugPrint('[CrtMu][Backend] body=${jsonEncode(payload)}');

    final response = await _postJson(
      url,
      payload,
      timeout: textTimeout,
      connectionErrorMessage:
          'Cannot reach backend at $url.\n'
          'If you are using a real phone, run Flutter with:\n'
          '--dart-define=BACKEND_BASE_URL=http://你的电脑局域网IP:3000',
      timeoutMessage:
          'Backend request timed out after ${textTimeout.inSeconds}s',
    );

    debugPrint('[CrtMu][Backend] status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] response=${response.body}');

    final root = _decodeJsonObject(response, 'Backend JSON root is not an object');
    _throwForBadStatus(response, 'Backend POST /chat failed');
    _throwForBackendError(root);

    final reply = root['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) {
      throw FormatException('Backend response missing reply: ${response.body}');
    }

    return reply;
  }

  Future<BackendUpload> uploadImage({
    required String filePath,
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/v1/uploads/image');
    debugPrint('[CrtMu][Backend] POST multipart $url');

    final request = http.MultipartRequest('POST', url)
      ..fields['userId'] = userId
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(uploadTimeout);
    } on SocketException catch (error) {
      throw HttpException(
        'Cannot reach backend upload endpoint at $url.\n'
        'If you are using a real phone, run Flutter with:\n'
        '--dart-define=BACKEND_BASE_URL=http://你的电脑局域网IP:3000\n'
        '$error',
      );
    } on TimeoutException catch (error) {
      throw TimeoutException(
        'Backend upload timed out after ${uploadTimeout.inSeconds}s: $error',
      );
    }

    final response = await http.Response.fromStream(
      streamed,
    ).timeout(uploadTimeout);

    debugPrint('[CrtMu][Backend] upload status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] upload response=${response.body}');

    final root = _decodeJsonObject(response, 'Upload JSON root is not an object');
    _throwForBadStatus(response, 'Backend POST /v1/uploads/image failed');

    final uploadJson = root['upload'];
    if (uploadJson is! Map) {
      throw FormatException(
        'Upload response missing upload payload: ${response.body}',
      );
    }

    return BackendUpload.fromJson(uploadJson.cast<String, dynamic>());
  }

  Future<ArtworkAnalysisResult> analyzeArtwork({
    required String uploadId,
    required String userId,
    required String studentName,
    required String title,
  }) async {
    final url = Uri.parse('$baseUrl/v1/artworks/analyze');
    final payload = <String, dynamic>{
      'userId': userId,
      'studentName': studentName,
      'title': title,
      'uploadId': uploadId,
    };

    debugPrint('[CrtMu][Backend] POST $url');
    debugPrint('[CrtMu][Backend] body=${jsonEncode(payload)}');

    final response = await _postJson(
      url,
      payload,
      timeout: analyzeTimeout,
      connectionErrorMessage: 'Cannot reach artwork analysis endpoint at $url',
      timeoutMessage:
          'Artwork analysis timed out after ${analyzeTimeout.inSeconds}s',
    );

    debugPrint('[CrtMu][Backend] analyze status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] analyze response=${response.body}');

    final root = _decodeJsonObject(response, 'Analyze JSON root is not an object');
    _throwForBadStatus(response, 'Backend POST /v1/artworks/analyze failed');

    return ArtworkAnalysisResult.fromJson(root);
  }

  Future<ReferenceGenerationResult> generateReferenceImage({
    required String artworkId,
  }) async {
    final url = Uri.parse('$baseUrl/v1/artworks/$artworkId/generate-reference');

    debugPrint('[CrtMu][Backend] POST $url');

    http.Response response;
    try {
      response = await _http
          .post(
            url,
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(referenceGenerationTimeout);
    } on SocketException catch (error) {
      throw HttpException(
        'Cannot reach reference generation endpoint at $url.\n$error',
      );
    } on TimeoutException catch (error) {
      throw TimeoutException(
        'Reference generation timed out after '
        '${referenceGenerationTimeout.inSeconds}s: $error',
      );
    }

    debugPrint('[CrtMu][Backend] generate status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] generate response=${response.body}');

    final root = _decodeJsonObject(response, 'Generate JSON root is not an object');
    _throwForBadStatus(
      response,
      'Backend POST /v1/artworks/$artworkId/generate-reference failed',
    );

    return ReferenceGenerationResult.fromJson(root);
  }

  Future<http.Response> _postJson(
    Uri url,
    Map<String, dynamic> payload, {
    required Duration timeout,
    required String connectionErrorMessage,
    required String timeoutMessage,
  }) async {
    try {
      return await _http
          .post(
            url,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } on SocketException catch (error) {
      throw HttpException('$connectionErrorMessage\n$error');
    } on TimeoutException catch (error) {
      throw TimeoutException('$timeoutMessage: $error');
    }
  }

  Map<String, dynamic> _decodeJsonObject(
    http.Response response,
    String errorPrefix,
  ) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw FormatException('$errorPrefix: ${response.body}');
    }

    return decoded.cast<String, dynamic>();
  }

  void _throwForBadStatus(http.Response response, String message) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '$message: HTTP ${response.statusCode} ${response.reasonPhrase}\n'
        '${response.body}',
      );
    }
  }

  void _throwForBackendError(Map<String, dynamic> root) {
    if (root['ok'] == false) {
      throw StateError(root['error']?.toString() ?? 'Backend returned ok=false');
    }
  }
}
