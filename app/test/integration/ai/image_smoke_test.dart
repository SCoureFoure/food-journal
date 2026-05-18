import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/worker_ai_service.dart';
import 'helpers/test_env.dart';

// Minimal 1×1 white JPEG — smallest valid JPEG payload.
// Tests that the worker accepts image bytes at the transport layer.
// Does NOT test model image-recognition capability.
const _minimalJpegBase64 =
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoH'
    'BwYIDAoMCwsKCwsNCxAQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQME'
    'BAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQU'
    'FBQUFBT/wAARCAABAAEDASIAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQ'
    'QAQAAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEBAAAAA'
    'AAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/ACWAA//Z';

void main() {
  group('[BVA] Image transport smoke', () {
    WorkerAiService? service;

    setUpAll(() {
      final url = readRootEnv('MEAL_PARSER_URL');
      if (url == null) return;
      final token = readRootEnv('TEST_AUTH_TOKEN');
      service = WorkerAiService(workerUrl: url, authToken: token);
    });

    test('minimal JPEG accepted by worker without 4xx transport rejection', () async {
      if (service == null) {
        markTestSkipped('MEAL_PARSER_URL not set');
        return;
      }

      final bytes = Uint8List.fromList(base64Decode(_minimalJpegBase64));
      final result = await service!.parseMeal(
        text: 'test meal for image transport verification',
        imageBytes: bytes,
        mealType: 'lunch',
        mealContext: null,
      );

      // Transport passes if the worker did not return a 4xx on the payload.
      // Model parse quality is irrelevant — this is a plumbing test only.
      if (!result.success) {
        final msg = result.errorMessage ?? '';
        expect(
          msg,
          isNot(matches(RegExp(r'Worker error 4\d\d'))),
          reason: 'Worker rejected image payload at transport layer: $msg',
        );
      }
    });
  });
}
