import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #87: changelog entries must be ordered by the
/// parsed `publishedAt` instant, not by lexicographic string comparison,
/// which mis-sorts mixed ISO-8601 formats (fractional seconds, non-UTC
/// offsets).
void main() {
  FeedbackClient clientWithEntries(List<Map<String, dynamic>> entries) {
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'entries': entries, 'hasMore': false, 'nextCursor': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  group('issue #87: changelog ordering by parsed instant', () {
    test('fetchChangelog orders a fractional-second entry newer than the '
        'same second without a fraction, regardless of server page order',
        () async {
      // The server returns the older (no-fraction) entry first. Byte-wise
      // 'Z' > '.', so the old string comparison picked the no-fraction
      // entry as newest; by instant, the .500 entry is newer.
      final client = clientWithEntries([
        {
          'id': 'cl_plain',
          'title': 'Plain second',
          'body': 'Body',
          'publishedAt': '2026-11-07T12:00:00Z',
        },
        {
          'id': 'cl_frac',
          'title': 'Half a second later',
          'body': 'Body',
          'publishedAt': '2026-11-07T12:00:00.500Z',
        },
      ]);

      final entries = await client.fetchChangelog();

      expect(entries.map((e) => e.id).toList(), ['cl_frac', 'cl_plain']);
    });

    test('fetchChangelog interleaves mixed ISO-8601 formats by true instant',
        () async {
      // Byte-descending order of these timestamps would be
      // [20:00:00+08:00, 12:00:01Z, 12:00:01.500Z, 11:59:59.000Z]; the true
      // instant order is [12:00:01.500Z, 12:00:01Z, 20:00:00+08:00
      // (= 12:00:00Z), 11:59:59.000Z]. The +08:00 entry and the .500 entry
      // both move relative to the byte order.
      final client = clientWithEntries([
        {
          'id': 'cl_offset_old',
          'title': 'Oldest',
          'body': 'Body',
          'publishedAt': '2026-11-07T11:59:59.000Z',
        },
        {
          'id': 'cl_plain',
          'title': 'Plain, third',
          'body': 'Body',
          'publishedAt': '2026-11-07T12:00:01Z',
        },
        {
          'id': 'cl_frac',
          'title': 'Fractional, newest',
          'body': 'Body',
          'publishedAt': '2026-11-07T12:00:01.500Z',
        },
        {
          'id': 'cl_offset',
          'title': 'Offset, second',
          'body': 'Body',
          'publishedAt': '2026-11-07T20:00:00+08:00',
        },
      ]);

      final entries = await client.fetchChangelog();

      expect(entries.map((e) => e.id).toList(), [
        'cl_frac',
        'cl_plain',
        'cl_offset',
        'cl_offset_old',
      ]);
    });

    test('fetchChangelog falls back to string comparison for unparseable '
        'publishedAt values without throwing', () async {
      final client = clientWithEntries([
        {
          'id': 'cl_parseable',
          'title': 'Parseable',
          'body': 'Body',
          'publishedAt': '2026-11-07T12:00:00Z',
        },
        {
          'id': 'cl_zzz',
          'title': 'Unparseable, byte-greatest',
          'body': 'Body',
          'publishedAt': 'zzz-unknown-format',
        },
        {
          'id': 'cl_maint',
          'title': 'Unparseable, middle',
          'body': 'Body',
          'publishedAt': 'maintenance-window',
        },
      ]);

      final entries = await client.fetchChangelog();

      // No throw; unparseable values keep the previous byte-descending
      // semantics relative to their peers ('zzz' > 'maintenance' > '2026…').
      expect(entries.map((e) => e.id).toList(), [
        'cl_zzz',
        'cl_maint',
        'cl_parseable',
      ]);
    });

    testWidgets('prepareChangelogOverlay(onlyIfUnseen: true) checks the '
        'truly newest entry as the seen-key when the newest page mixes '
        'fractional and non-fractional timestamps', (tester) async {
      final storage = MemoryTokenStorage();
      // The server page puts the older no-fraction entry first, so the old
      // string comparison treated 1.9.0 as the latest release.
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: const PublicAppConfig(
          appId: 'app_123',
          appKey: 'app_test_123',
          slug: 'test-app',
          name: 'Test App',
          allowPublic: true,
          allowedPlatforms: [],
          maxAttachmentBytes: 1048576,
          allowAnonymousRoadmap: true,
          allowAnonymousVote: true,
          allowAnonymousFeedback: true,
          allowAnonymousChangelog: true,
          sdk: SdkAppearance(
            features: SdkFeatures(changelog: true),
          ),
        ),
        storage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/changelog')) {
            return http.Response(
              jsonEncode({
                'entries': [
                  {
                    'id': 'cl_190',
                    'title': '1.9.0',
                    'body': 'Body',
                    'versionLabel': '1.9.0',
                    'publishedAt': '2026-11-07T12:00:00Z',
                  },
                  {
                    'id': 'cl_200',
                    'title': '2.0.0',
                    'body': 'Body',
                    'versionLabel': '2.0.0',
                    'publishedAt': '2026-11-07T12:00:00.500Z',
                  },
                ],
                'hasMore': false,
                'nextCursor': null,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );

      // Mark the byte-sorted (wrong) winner as seen; the truly newest
      // release 2.0.0 must still surface.
      await client.markChangelogSeen('1.9.0');

      final overlay = await client.prepareChangelogOverlay(
        onlyIfUnseen: true,
        isAnonymous: false,
      );

      expect(overlay, isNotNull);
      expect(overlay!.entries.first.versionLabel, '2.0.0');
      expect(overlay.entries.map((e) => e.versionLabel).toList(),
          ['2.0.0', '1.9.0']);

      // Once 2.0.0 itself is marked seen, the overlay is suppressed.
      await client.markChangelogSeen('2.0.0');
      final suppressed = await client.prepareChangelogOverlay(
        onlyIfUnseen: true,
        isAnonymous: false,
      );
      expect(suppressed, isNull);
    });
  });
}
