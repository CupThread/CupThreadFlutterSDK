import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Storage adapter whose reads wait on a gate, to observe the cold-start
/// restoration race deterministically.
class _GatedStorage implements TokenStorageAdapter {
  _GatedStorage(this._seeded);

  final String? _seeded;
  final Completer<void> gate = Completer<void>();
  int readCount = 0;

  @override
  Future<String?> getItem(String key) async {
    readCount++;
    await gate.future;
    return _seeded;
  }

  @override
  Future<void> setItem(String key, String value) async {
    _written[key] = value;
  }

  final Map<String, String> _written = {};
}

FeedbackClient _mockClient() {
  return FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_test_123',
    ),
    httpClient: MockClient((request) async {
      if (request.url.path.contains('/public/config/')) {
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{"error":"not found"}', 404);
    }),
  );
}

/// Regression coverage for issue #96: the theme scope treated only `null`
/// as anonymous, while the client's documented contract is "non-blank
/// wins" — `_resolveIdentity` trims a blank `userToken` to absent and
/// `_sendJson` omits the `X-User-Token` header for an empty string. A host
/// following the common `String _token = '';` default therefore produced a
/// third, broken state: the scope reported an authenticated session while
/// every request went out with no identity at all, so gated votes and
/// boards skipped the sign-in guidance and landed in doomed 401/403 loops.
/// A blank host token now behaves exactly like `null` at the theme
/// boundary.
void main() {
  PublicAppConfig createMockConfig({
    bool allowAnonymousRoadmap = true,
    bool allowAnonymousVote = true,
  }) {
    return PublicAppConfig(
      appId: 'app_123',
      appKey: 'app_test_123',
      slug: 'test-app',
      name: 'Test App',
      allowPublic: true,
      allowedPlatforms: const [FeedbackPlatform.ios, FeedbackPlatform.android],
      maxAttachmentBytes: 1048576,
      allowAnonymousRoadmap: allowAnonymousRoadmap,
      allowAnonymousVote: allowAnonymousVote,
      allowAnonymousFeedback: true,
      allowAnonymousChangelog: true,
      sdk: const SdkAppearance(
        features: SdkFeatures(
          feedback: true,
          featureRequests: true,
          roadmap: true,
          changelog: true,
        ),
      ),
    );
  }

  FeedbackClient clientWith(
    MockClient fn, {
    required PublicAppConfig config,
  }) =>
      FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: fn,
        initialConfig: config,
      );

  Widget host(
    FeedbackClient client, {
    String? userToken,
    required PublicAppConfig config,
  }) =>
      MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: FeedbackPlatform.ios,
          userToken: userToken,
          child: const FeatureRequestsScreen(),
        ),
      );

  /// Seeds the shared store's durable identity to a known value so header
  /// comparisons are exact.
  Future<UserTokenStore> seedStore(String token) async {
    final storage = MemoryTokenStorage();
    await storage.setItem(UserTokenStore.storageKey, token);
    UserTokenStore.configure(storage);
    return UserTokenStore.shared;
  }

  testWidgets(
      'token transitions during an unresolved storage read settle on the '
      'stored identity', (tester) async {
    // A real → blank → real → blank host sequence, all before the gated
    // storage read resolves: every blank is a sign-out (re-gate + restore),
    // every real token wins immediately, and once the read finally lands
    // the resolved identity is the persisted token — a stale in-flight
    // restore must not resurrect an identity the host has since replaced,
    // and the final blank must not be shadowed by an earlier real token.
    final storage = _GatedStorage('persisted-token-123');
    UserTokenStore.configure(storage);

    Widget hostWith(String? userToken) => MaterialApp(
          home: CupThreadTheme(
            client: _mockClient(),
            userToken: userToken,
            child: Builder(
              builder: (context) => Text(
                'token:${CupThreadTheme.userTokenOf(context)}',
              ),
            ),
          ),
        );

    // Real token: published immediately, no storage read started.
    await tester.pumpWidget(hostWith('usr_tok_first'));
    expect(find.text('token:usr_tok_first'), findsOneWidget);
    expect(storage.readCount, 0);

    // Blank: a sign-out — re-gate (child deferred) and restore from storage.
    await tester.pumpWidget(hostWith(''));
    expect(find.textContaining('token:'), findsNothing);

    // Real token again while the read is still parked.
    await tester.pumpWidget(hostWith('usr_tok_second'));
    expect(find.text('token:usr_tok_second'), findsOneWidget);

    // Blank again while the read is still parked: re-gate; the restore
    // must finish with the stored identity, not either real token.
    await tester.pumpWidget(hostWith('  '));
    expect(find.textContaining('token:'), findsNothing);
    expect(storage.readCount, 1);

    storage.gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('token:persisted-token-123'), findsOneWidget);
  });

  testWidgets(
      'a blank userToken behaves like null on a sign-in-only board: '
      'no request fires and sign-in guidance renders', (tester) async {
    final config = createMockConfig(allowAnonymousRoadmap: false);
    var fetchRequestsCalled = false;

    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          fetchRequestsCalled = true;
          return http.Response(
            jsonEncode({
              'error': 'Sign in is required to view this roadmap',
              'code': 'authentication_required',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
      config: config,
    );
    await seedStore('store-identity-1');

    // The empty-string default idiom: the host intends "anonymous until
    // signed in", which is exactly what a blank value must deliver.
    await tester.pumpWidget(host(client, userToken: '', config: config));
    await tester.pumpAndSettle();

    expect(CupThreadTheme.isAnonymous(
      tester.element(find.byType(FeatureRequestsScreen)),
    ), isTrue);
    // Zero gated requests leave the client — the gate is not bypassed.
    expect(fetchRequestsCalled, isFalse);
    // Sign-in guidance instead of a doomed 401 loop.
    expect(find.text('Sign-in is required.'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // The whitespace-only variant (a text-bound token store) behaves the
    // same way.
    await tester.pumpWidget(host(client, userToken: '   ', config: config));
    await tester.pumpAndSettle();

    expect(CupThreadTheme.isAnonymous(
      tester.element(find.byType(FeatureRequestsScreen)),
    ), isTrue);
    expect(fetchRequestsCalled, isFalse);
    expect(find.text('Sign-in is required.'), findsOneWidget);
  });

  testWidgets(
      'a blank userToken on a vote-gated board shows the sign-in snackbar '
      'instead of sending a headerless vote', (tester) async {
    final config = createMockConfig(
      allowAnonymousRoadmap: true,
      allowAnonymousVote: false,
    );
    var votePosted = false;

    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'requests': [
                {
                  'id': 'fr_1',
                  'appId': 'app_123',
                  'title': 'Dark mode support',
                  'description': 'Add full dark mode theme',
                  'status': 'under_review',
                  'approved': true,
                  'voteCount': 5,
                  'hasVoted': false,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
              ],
              'totalCount': 1,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/vote')) {
          votePosted = true;
          return http.Response(
            jsonEncode({'error': 'unauthorized'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      config: config,
    );
    await seedStore('store-identity-1');

    await tester.pumpWidget(host(client, userToken: '', config: config));
    await tester.pumpAndSettle();

    // The board loaded under the durable anonymous identity; a tap must
    // produce sign-in guidance, not a headerless POST the server answers
    // with a raw 401.
    expect(find.byType(VoteButton), findsOneWidget);
    await tester.tap(find.byType(VoteButton));
    await tester.pumpAndSettle();

    expect(votePosted, isFalse);
    expect(find.text('Sign-in is required to vote.'), findsOneWidget);
    expect(find.byType(VoteButton), findsOneWidget);
    // The optimistic vote never applied.
    expect(tester.widget<VoteButton>(find.byType(VoteButton)).hasVoted,
        isFalse);
  });

  testWidgets(
      'a blank userToken and null produce identical request identities',
      (tester) async {
    final config = createMockConfig(allowAnonymousRoadmap: true);
    final blankRunHeaders = <String?>[];
    final nullRunHeaders = <String?>[];

    MockClient recorder(List<String?> sink) => MockClient((request) async {
          if (request.url.path == '/api/v1/feature-requests') {
            sink.add(request.headers['X-User-Token']);
            return http.Response(
              jsonEncode({
                'requests': [],
                'totalCount': 0,
                'hasMore': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.contains('/versions')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 200);
        });

    await seedStore('store-identity-1');
    final blankClient =
        clientWith(recorder(blankRunHeaders), config: config);
    await tester.pumpWidget(host(blankClient, userToken: '', config: config));
    await tester.pumpAndSettle();

    // Unmount so the second mount cannot reuse the screen State — the
    // screen dedupes reloads by identity, and both mounts resolve the same
    // anonymous identity here.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    await seedStore('store-identity-1');
    final nullClient = clientWith(recorder(nullRunHeaders), config: config);
    await tester.pumpWidget(host(nullClient, userToken: null, config: config));
    await tester.pumpAndSettle();

    // Both sessions present the same resolved anonymous store identity —
    // a blank host token must not downgrade the header to absent.
    expect(blankRunHeaders, ['store-identity-1']);
    expect(nullRunHeaders, ['store-identity-1']);
  });

  testWidgets(
      'blank ↔ real-token transitions behave like the null equivalents',
      (tester) async {
    final config = createMockConfig(allowAnonymousRoadmap: true);
    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'requests': [],
              'totalCount': 0,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      config: config,
    );
    await seedStore('store-identity-1');

    Widget identityProbe() => Builder(
          builder: (context) => Text(
            'token:${CupThreadTheme.userTokenOf(context)} '
            'anon:${CupThreadTheme.isAnonymous(context)}',
          ),
        );

    Widget hostWith(String? userToken) => MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            platformOverride: FeedbackPlatform.ios,
            userToken: userToken,
            child: identityProbe(),
          ),
        );

    // Blank: the durable anonymous identity is published, session anonymous.
    await tester.pumpWidget(hostWith(''));
    await tester.pumpAndSettle();
    expect(find.text('token:store-identity-1 anon:true'), findsOneWidget);

    // Sign-in with a real token (raw differ, blank → present): the host
    // identity wins and the session reports authenticated.
    await tester.pumpWidget(hostWith('usr_tok_signed_in'));
    await tester.pumpAndSettle();
    expect(find.text('token:usr_tok_signed_in anon:false'), findsOneWidget);

    // null ↔ blank is a no-op for the resolved identity: switching from a
    // real token to blank re-gates to the durable identity, exactly like
    // switching to null.
    await tester.pumpWidget(hostWith(''));
    await tester.pumpAndSettle();
    expect(find.text('token:store-identity-1 anon:true'), findsOneWidget);

    // And a blank → blank host rebuild must not re-gate or flicker the
    // resolved identity away.
    await tester.pumpWidget(hostWith('   '));
    await tester.pumpAndSettle();
    expect(find.text('token:store-identity-1 anon:true'), findsOneWidget);
  });
}
