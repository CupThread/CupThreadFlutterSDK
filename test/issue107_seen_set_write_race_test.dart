import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #107: `_updateSeenVersions` was an
/// unsynchronized read-modify-write across `await`s, so two concurrent
/// `markChangelogSeen`/`markChangelogEntrySeen` calls both anchored on the
/// same stored value and the last `setItem` silently dropped the other's
/// keys — the lost mark re-showed the What's-New overlay for an
/// already-dismissed release. Writes are now serialized through a future
/// chain (the same pattern `UserTokenStore._persist` uses for the identity
/// token), and a failed write no longer poisons subsequent marks.

/// A [TokenStorageAdapter] whose reads and writes complete through
/// [Completer] gates so the test controls the interleaving deterministically.
/// Gates are indexed by call order; once the gated calls have been issued,
/// completing a gate releases that call. Calls beyond the gate count run
/// ungated.
class _GatedStorage implements TokenStorageAdapter {
  final Map<String, String> _data = {};
  final List<Completer<void>> _readGates = [];
  final List<Completer<void>> _writeGates = [];
  final List<Object?> _writeErrors = [];
  int _reads = 0;
  int _writes = 0;

  void gateReads(int n) {
    for (var i = 0; i < n; i++) {
      _readGates.add(Completer<void>());
    }
  }

  void gateWrites(int n, [Object? error]) {
    for (var i = 0; i < n; i++) {
      _writeGates.add(Completer<void>());
      _writeErrors.add(error);
    }
  }

  void releaseReads(int n) {
    for (var i = 0; i < n; i++) {
      _readGates[i].complete();
    }
  }

  void releaseWrites(int n) {
    for (var i = 0; i < n; i++) {
      _writeGates[i].complete();
    }
  }

  @override
  Future<String?> getItem(String key) async {
    final i = _reads++;
    if (i < _readGates.length) await _readGates[i].future;
    return _data[key];
  }

  @override
  Future<void> setItem(String key, String value) async {
    final i = _writes++;
    if (i < _writeGates.length) await _writeGates[i].future;
    if (i < _writeErrors.length) {
      final error = _writeErrors[i];
      if (error != null) throw error;
    }
    _data[key] = value;
  }
}

void main() {
  FeedbackClient buildClient({
    required String appKey,
    TokenStorageAdapter? storage,
  }) {
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: appKey,
      ),
      storage: storage,
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

  group('issue #107 — concurrent seen-set marks compose', () {
    test('two concurrent markChangelogSeen calls both survive', () async {
      final storage = _GatedStorage()..gateReads(2)..gateWrites(2);
      final client = buildClient(appKey: 'app_107_race', storage: storage);

      // Both marks start without awaiting; each is parked mid-flight (read
      // gate, then write gate) so neither write can land before both reads
      // have run — the interleaving that used to drop a key.
      final f1 = client.markChangelogSeen('v1');
      final f2 = client.markChangelogSeen('v2');
      storage.releaseReads(2);
      storage.releaseWrites(2);
      await Future.wait([f1, f2]);

      final raw =
          await storage.getItem('cupthread_seen_changelog_app_107_race');
      final decoded = (jsonDecode(raw!) as List<dynamic>).cast<String>();
      expect(decoded, containsAll(<String>['v1', 'v2']),
          reason: 'neither mark may overwrite the other');
    });

    test('markChangelogEntrySeen racing markChangelogSeen keeps all keys',
        () async {
      final storage = _GatedStorage()..gateReads(2)..gateWrites(2);
      final client =
          buildClient(appKey: 'app_107_entry_race', storage: storage);

      const entry = ChangelogEntry(
        id: 'cl_race',
        title: 'Release',
        body: 'Body',
        publishedAt: '2026-11-01T12:00:00Z',
        versionLabel: '2.0, beta',
      );

      final f1 = client.markChangelogEntrySeen(entry);
      final f2 = client.markChangelogSeen('v3');
      storage.releaseReads(2);
      storage.releaseWrites(2);
      await Future.wait([f1, f2]);

      expect(await client.hasSeenChangelog('cl_race'), isTrue);
      expect(await client.hasSeenChangelog('2.0, beta'), isTrue);
      expect(await client.hasSeenChangelog('v3'), isTrue);
    });

    test('a failed write does not poison subsequent marks', () async {
      final storage = _GatedStorage()
        ..gateWrites(1, Exception('disk full'))
        ..releaseWrites(1);
      final client = buildClient(appKey: 'app_107_fail', storage: storage);

      // The first write throws; the mutators swallow the error and the
      // chained queue must stay usable for the next mark.
      await client.markChangelogSeen('v1');
      expect(await client.hasSeenChangelog('v1'), isFalse);

      await client.markChangelogSeen('v2');
      expect(await client.hasSeenChangelog('v2'), isTrue,
          reason: 'the next mark after a failed write must still persist');
    });
  });
}
