import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #98: the changelog seen-set used to persist a
/// comma-joined string through `TokenStorageAdapter`, so a host-authored
/// `versionLabel` containing a comma corrupted the seen state and re-showed
/// the What's-New overlay on every launch. The set is now persisted as a JSON
/// array (delimiter-free round-trip for arbitrary key text) with a legacy
/// comma-joined fallback on read, a capped history, and the system-authored
/// `entry.id` as the canonical key.
void main() {
  const entryJson = <String, dynamic>{
    'entries': [
      {
        'id': 'cl_comma',
        'title': 'Release with a comma label',
        'body': 'Body',
        'versionLabel': '1.2, hotfix',
        'publishedAt': '2026-11-01T12:00:00Z',
      },
      {
        'id': 'cl_plain',
        'title': 'Older release',
        'body': 'Body',
        'versionLabel': '1.1.0',
        'publishedAt': '2026-10-01T12:00:00Z',
      },
    ],
    'hasMore': false,
    'nextCursor': null,
  };

  FeedbackClient buildClient({
    required String appKey,
    TokenStorageAdapter? storage,
    http.Client? httpClient,
  }) {
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: appKey,
      ),
      storage: storage,
      httpClient: httpClient,
      initialConfig: PublicAppConfig(
        appId: 'app_123',
        appKey: appKey,
        slug: 'test-app',
        name: 'Test App',
        allowPublic: true,
        allowedPlatforms: [],
        maxAttachmentBytes: 1048576,
        allowAnonymousRoadmap: true,
        allowAnonymousVote: true,
        allowAnonymousFeedback: true,
        allowAnonymousChangelog: true,
        sdk: const SdkAppearance(
          features: SdkFeatures(changelog: true),
        ),
      ),
    );
  }

  group('issue #98 — seen-set storage format', () {
    test('a versionLabel containing a comma round-trips exactly', () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_comma', storage: storage);

      await client.markChangelogSeen('1.2, hotfix');

      expect(await client.hasSeenChangelog('1.2, hotfix'), isTrue);
      expect(await client.hasSeenChangelog('hotfix'), isFalse,
          reason: 'no fragments are produced by the new format');
      expect(await client.hasSeenChangelog('1.2'), isFalse);
    });

    test('keys survive round-trips with arbitrary label text', () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_arbitrary', storage: storage);

      const keys = <String>[
        '1.2, hotfix',
        '版本 1.2，2026年11月',
        'multi\nline\nlabel',
        'padded',
        '[brackets], "quotes", {json}',
        'null',
        '123',
      ];
      for (final key in keys) {
        await client.markChangelogSeen(key);
      }

      for (final key in keys) {
        expect(await client.hasSeenChangelog(key), isTrue, reason: key);
      }
      // Keys are stored whole and trimmed, never split on punctuation.
      expect(await client.hasSeenChangelog('  padded  '), isTrue);
      final raw = await storage.getItem('cupthread_seen_changelog_app_98_arbitrary');
      final decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded, hasLength(keys.length));
      expect(decoded, containsAll(keys));
    });

    test('stored value is a JSON array', () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_json', storage: storage);

      await client.markChangelogSeen('1.2, hotfix');
      await client.markChangelogSeen('2.0.0');

      final raw = await storage.getItem('cupthread_seen_changelog_app_98_json');
      final decoded = jsonDecode(raw!);
      expect(decoded, isA<List<dynamic>>());
      expect(decoded, containsAll(<String>['1.2, hotfix', '2.0.0']));
    });

    test('legacy comma-joined storage value is still recognized', () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_legacy', storage: storage);

      // A value written by the pre-#98 format.
      await storage.setItem('cupthread_seen_changelog_app_98_legacy', '1.0.0,1.1.0');

      expect(await client.hasSeenChangelog('1.0.0'), isTrue);
      expect(await client.hasSeenChangelog('1.1.0'), isTrue);
      expect(await client.hasSeenChangelog('1.2.0'), isFalse);
    });

    test('marking a new version migrates legacy entries into the JSON array',
        () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_migrate', storage: storage);

      await storage.setItem('cupthread_seen_changelog_app_98_migrate', '1.0.0,1.1.0');
      await client.markChangelogSeen('1.2.0');

      // Legacy entries survive the migration...
      expect(await client.hasSeenChangelog('1.0.0'), isTrue);
      expect(await client.hasSeenChangelog('1.1.0'), isTrue);
      expect(await client.hasSeenChangelog('1.2.0'), isTrue);
      // ...and the stored value is now a JSON array holding all three.
      final raw = await storage.getItem('cupthread_seen_changelog_app_98_migrate');
      final decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded, hasLength(3));
      expect(decoded, containsAll(<String>['1.0.0', '1.1.0', '1.2.0']));
    });

    test('seen history is capped to the most recent keys', () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_cap', storage: storage);

      for (var i = 0; i < 60; i++) {
        await client.markChangelogSeen('v$i');
      }

      // The oldest ten are dropped; the newest fifty survive.
      for (var i = 0; i < 10; i++) {
        expect(await client.hasSeenChangelog('v$i'), isFalse, reason: 'v$i');
      }
      for (var i = 10; i < 60; i++) {
        expect(await client.hasSeenChangelog('v$i'), isTrue, reason: 'v$i');
      }

      final raw = await storage.getItem('cupthread_seen_changelog_app_98_cap');
      expect((jsonDecode(raw!) as List<dynamic>), hasLength(50));
    });

    test('blank keys are never stored', () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_blank', storage: storage);

      await client.markChangelogSeen('   ');
      await client.markChangelogSeen('');

      expect(
        await storage.getItem('cupthread_seen_changelog_app_98_blank'),
        isNull,
      );
    });

    test('markChangelogEntrySeen records both the entry id and its label',
        () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_entry', storage: storage);

      const entry = ChangelogEntry(
        id: 'cl_entry_1',
        title: 'Release',
        body: 'Body',
        publishedAt: '2026-11-01T12:00:00Z',
        versionLabel: '1.2, hotfix',
      );
      await client.markChangelogEntrySeen(entry);

      expect(await client.hasSeenChangelog('cl_entry_1'), isTrue);
      expect(await client.hasSeenChangelog('1.2, hotfix'), isTrue);
    });

    test('a comma label marked seen through the overlay flow suppresses the overlay',
        () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(
        appKey: 'app_98_overlay',
        storage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/changelog')) {
            return http.Response(
              jsonEncode(entryJson),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );

      // The latest entry's label contains a comma — under the pre-#98 format
      // this state could never be persisted, so the overlay re-showed every
      // launch.
      await client.markChangelogEntrySeen(
        const ChangelogEntry(
          id: 'cl_comma',
          title: 'Release with a comma label',
          body: 'Body',
          publishedAt: '2026-11-01T12:00:00Z',
          versionLabel: '1.2, hotfix',
        ),
      );

      final overlay = await client.prepareChangelogOverlay(
        onlyIfUnseen: true,
        isAnonymous: false,
      );
      expect(overlay, isNull);
    });

    test('a legacy label-only seen key still suppresses the overlay', () async {
      final storage = MemoryTokenStorage();
      final client = buildClient(
        appKey: 'app_98_legacy_overlay',
        storage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/changelog')) {
            // The newest release is '1.1.0' — the label an older SDK
            // recorded in the legacy seen value above.
            return http.Response(
              jsonEncode({
                'entries': [
                  {
                    'id': 'cl_latest',
                    'title': 'Older release',
                    'body': 'Body',
                    'versionLabel': '1.1.0',
                    'publishedAt': '2026-10-01T12:00:00Z',
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

      // Older SDK versions keyed the seen check on the version label. A
      // comma-free label written by the pre-#98 format still suppresses the
      // overlay for that release after the upgrade.
      await storage.setItem(
        'cupthread_seen_changelog_app_98_legacy_overlay',
        '1.0.0,1.1.0',
      );

      final overlay = await client.prepareChangelogOverlay(
        onlyIfUnseen: true,
        isAnonymous: false,
      );
      expect(overlay, isNull,
          reason: 'the label key written by an older SDK still counts as seen');
    });

    testWidgets('closing the overlay marks a comma label seen', (tester) async {
      final storage = MemoryTokenStorage();
      final client = buildClient(appKey: 'app_98_widget', storage: storage);

      const entry = ChangelogEntry(
        id: 'cl_widget',
        title: 'Release 1.2, hotfix',
        body: 'Body',
        publishedAt: '2026-11-01T12:00:00Z',
        versionLabel: '1.2, hotfix',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            child: const Scaffold(
              body: ChangelogOverlay(
                entries: [entry],
                config: ChangelogOverlayConfig(),
                autoMarkSeen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(await client.hasSeenChangelog('1.2, hotfix'), isTrue);
      expect(await client.hasSeenChangelog('cl_widget'), isTrue);
    });
  });
}
