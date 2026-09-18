import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  group('SdkAttributeSigner', () {
    test('canonicalNumber formats numbers per cpt-user-attrs-v1 spec', () {
      expect(SdkAttributeSigner.canonicalNumber(0), '0');
      expect(SdkAttributeSigner.canonicalNumber(0.0), '0');
      expect(SdkAttributeSigner.canonicalNumber(12), '12');
      expect(SdkAttributeSigner.canonicalNumber(1200), '1200');
      expect(SdkAttributeSigner.canonicalNumber(99.5), '99.5');
      expect(SdkAttributeSigner.canonicalNumber(299.5), '299.5');
      expect(SdkAttributeSigner.canonicalNumber(99.05), '99.05');
      expect(SdkAttributeSigner.canonicalNumber(0.1), '0.1');
      expect(SdkAttributeSigner.canonicalNumber(0.01), '0.01');
      expect(SdkAttributeSigner.canonicalNumber(100), '100');
      expect(SdkAttributeSigner.canonicalNumber(1000000), '1000000');
      expect(SdkAttributeSigner.canonicalNumber(1.234), '1.23');
      expect(SdkAttributeSigner.canonicalNumber(1.235), '1.24');
      expect(SdkAttributeSigner.canonicalNumber(12.30), '12.3');

      expect(
        () => SdkAttributeSigner.canonicalNumber(double.nan),
        throwsArgumentError,
      );
      expect(
        () => SdkAttributeSigner.canonicalNumber(double.infinity),
        throwsArgumentError,
      );
    });

    test('canonicalize constructs correct canonical string with all fields', () {
      final canonical = SdkAttributeSigner.canonicalize(
        appKey: 'app_testkey1234567',
        userToken: '00000000-0000-4000-8000-000000000001',
        isPaying: true,
        plan: 'pro',
        mrr: 12,
        currency: 'usd',
        timestamp: 1700000000,
      );

      expect(
        canonical,
        'cpt-user-attrs-v1\n'
        'app_testkey1234567\n'
        '00000000-0000-4000-8000-000000000001\n'
        'true\n'
        'pro\n'
        '12\n'
        'usd\n'
        '1700000000',
      );
    });

    test('canonicalize marks absent fields as unset and null fields as null', () {
      final canonical = SdkAttributeSigner.canonicalize(
        appKey: 'app_testkey1234567',
        userToken: '00000000-0000-4000-8000-000000000001',
        raw: {
          'isPaying': false,
          'plan': null,
          'mrr': 299.5,
          // currency is absent
        },
        timestamp: 1700000000,
      );

      expect(
        canonical,
        'cpt-user-attrs-v1\n'
        'app_testkey1234567\n'
        '00000000-0000-4000-8000-000000000001\n'
        'false\n'
        'null\n'
        '299.5\n'
        'unset\n'
        '1700000000',
      );
    });

    test('sign matches exact server-side HMAC-SHA256 test vectors', () {
      // Vector 1: Full payload with pro plan and 12 MRR
      final sig1 = SdkAttributeSigner.sign(
        secret: '7' * 64,
        appKey: 'app_testkey1234567',
        userToken: '00000000-0000-4000-8000-000000000001',
        isPaying: true,
        plan: 'pro',
        mrr: 12,
        currency: 'usd',
        timestamp: 1700000000,
      );
      expect(sig1, 'a18280f71c28b3d57412815b6096987e31ca5a510915ab975e1fb1f9a586442d');

      // Vector 2: Explicit null plan, 299.5 MRR, unset currency
      final sig2 = SdkAttributeSigner.sign(
        secret: 'secret_key_12345',
        appKey: 'app_testkey1234567',
        userToken: '00000000-0000-4000-8000-000000000001',
        raw: {
          'isPaying': false,
          'plan': null,
          'mrr': 299.5,
        },
        timestamp: 1700000000,
      );
      expect(sig2, '9fa9f8bd62f67bf836ac2a9f8984483b5e064302677e1b82f16e86da8ca2648f');
    });

    test('sign throws when secret is empty', () {
      expect(
        () => SdkAttributeSigner.sign(
          secret: '',
          appKey: 'app_123',
          userToken: 'token_123',
          timestamp: 1700000000,
          isPaying: true,
        ),
        throwsArgumentError,
      );
    });

    test('verify checks signature validity and freshness window', () {
      const secret = 'test_secret_key';
      const appKey = 'app_key_test';
      const userToken = '00000000-0000-4000-8000-000000000001';
      const timestamp = 1700000000;

      final signature = SdkAttributeSigner.sign(
        secret: secret,
        appKey: appKey,
        userToken: userToken,
        isPaying: true,
        mrr: 99.0,
        timestamp: timestamp,
      );

      // Valid signature within freshness window
      expect(
        SdkAttributeSigner.verify(
          secret: secret,
          signature: signature,
          appKey: appKey,
          userToken: userToken,
          isPaying: true,
          mrr: 99.0,
          timestamp: timestamp,
          currentEpochSeconds: timestamp + 60,
        ),
        isTrue,
      );

      // Case-insensitive hex verification
      expect(
        SdkAttributeSigner.verify(
          secret: secret,
          signature: signature.toUpperCase(),
          appKey: appKey,
          userToken: userToken,
          isPaying: true,
          mrr: 99.0,
          timestamp: timestamp,
          currentEpochSeconds: timestamp,
        ),
        isTrue,
      );

      // Wrong secret
      expect(
        SdkAttributeSigner.verify(
          secret: 'wrong_secret',
          signature: signature,
          appKey: appKey,
          userToken: userToken,
          isPaying: true,
          mrr: 99.0,
          timestamp: timestamp,
          currentEpochSeconds: timestamp,
        ),
        isFalse,
      );

      // Tampered payload
      expect(
        SdkAttributeSigner.verify(
          secret: secret,
          signature: signature,
          appKey: appKey,
          userToken: userToken,
          isPaying: true,
          mrr: 1000.0, // altered
          timestamp: timestamp,
          currentEpochSeconds: timestamp,
        ),
        isFalse,
      );

      // Stale timestamp (> 300 seconds drift)
      expect(
        SdkAttributeSigner.verify(
          secret: secret,
          signature: signature,
          appKey: appKey,
          userToken: userToken,
          isPaying: true,
          mrr: 99.0,
          timestamp: timestamp,
          currentEpochSeconds: timestamp + 301,
        ),
        isFalse,
      );
    });
  });

  group('FeedbackClient.updateUserAttributes HMAC signing', () {
    const appKey = 'app_testkey1234567';
    const userToken = '00000000-0000-4000-8000-000000000001';
    final secret = '7' * 64;

    test('automatically signs payment attributes when sdkSigningSecret is configured', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'ok': true, 'updatedAt': '2026-09-17T00:00:00Z'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
          sdkSigningSecret: secret,
        ),
        httpClient: mockClient,
      );

      final result = await client.updateUserAttributes(
        userToken: userToken,
        isPaying: true,
        plan: 'pro',
        mrr: 12,
        currency: 'usd',
        timestamp: 1700000000,
      );

      expect(result.ok, isTrue);
      expect(result.updatedAt, '2026-09-17T00:00:00Z');

      expect(capturedRequest.method, 'PUT');
      expect(
        capturedRequest.url.toString(),
        'https://api.cupthread.com/api/v1/public/apps/$appKey/user',
      );
      expect(capturedRequest.headers['x-user-token'], userToken);
      expect(capturedRequest.headers['content-type'], startsWith('application/json'));

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['userToken'], userToken);
      expect(body['isPaying'], isTrue);
      expect(body['plan'], 'pro');
      expect(body['mrr'], 12);
      expect(body['currency'], 'usd');
      expect(body['timestamp'], 1700000000);
      expect(body['signature'], 'a18280f71c28b3d57412815b6096987e31ca5a510915ab975e1fb1f9a586442d');
    });

    test('allows per-call signingSecret override', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'ok': true, 'updatedAt': '2026-09-17T00:00:00Z'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
          // No global secret configured
        ),
        httpClient: mockClient,
      );

      await client.updateUserAttributes(
        userToken: userToken,
        isPaying: true,
        mrr: 12,
        plan: 'pro',
        currency: 'usd',
        signingSecret: secret,
        timestamp: 1700000000,
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['signature'], 'a18280f71c28b3d57412815b6096987e31ca5a510915ab975e1fb1f9a586442d');
      expect(body['timestamp'], 1700000000);
    });

    test('leaves non-payment attributes unsigned', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'ok': true, 'updatedAt': '2026-09-17T00:00:00Z'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
          sdkSigningSecret: secret,
        ),
        httpClient: mockClient,
      );

      // Currency only, no isPaying/plan/mrr
      await client.updateUserAttributes(
        userToken: userToken,
        currency: 'EUR',
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['currency'], 'EUR');
      expect(body.containsKey('signature'), isFalse);
      expect(body.containsKey('timestamp'), isFalse);
      expect(body.containsKey('isPaying'), isFalse);
    });

    test('accepts explicit precomputed signature and timestamp', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'ok': true, 'updatedAt': '2026-09-17T00:00:00Z'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
        ),
        httpClient: mockClient,
      );

      const customSig = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      await client.updateUserAttributes(
        userToken: userToken,
        isPaying: true,
        signature: customSig,
        timestamp: 1700000000,
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['signature'], customSig);
      expect(body['timestamp'], 1700000000);
    });

    test('sends unsigned when payment attributes provided without secret (allowing server 422)', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'error': 'payment_attributes_require_signature',
            'code': 'payment_attributes_require_signature',
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
          // No secret
        ),
        httpClient: mockClient,
      );

      await expectLater(
        client.updateUserAttributes(
          userToken: userToken,
          isPaying: true,
        ),
        throwsA(isA<UnexpectedStatusException>().having((e) => e.status, 'status', 422)),
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body.containsKey('signature'), isFalse);
      expect(body.containsKey('timestamp'), isFalse);
    });
  });
}
