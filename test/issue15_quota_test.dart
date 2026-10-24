import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

FeedbackClient _clientReturning(http.Response Function() responder) =>
    FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: MockClient((request) async => responder()),
    );

void main() {
  group('issue #15: HTTP 402 quota rejection maps to SubmissionQuotaException', () {
    test('tier_limit_submissions code maps to typed quota error', () async {
      final client = _clientReturning(() => _jsonResponse(
            {
              'error': 'Monthly submission quota reached',
              'code': 'tier_limit_submissions',
            },
            402,
          ));

      await expectLater(
        client.submitFeatureRequest(
          const FeatureRequestDraft(title: 'Dark mode', description: 'Please add dark mode.'),
          userToken: 'tok_user_1',
        ),
        throwsA(
          isA<SubmissionQuotaException>()
              .having((e) => e.reason, 'reason',
                  SubmissionQuotaReason.tierLimitSubmissions)
              .having((e) => e.code, 'code', 'tier_limit_submissions')
              .having((e) => e.status, 'status', 402),
        ),
      );
    });

    test('subscription_inactive code maps to typed inactive-subscription error',
        () async {
      final client = _clientReturning(() => _jsonResponse(
            {
              'error': 'Workspace subscription is inactive',
              'code': 'subscription_inactive',
            },
            402,
          ));

      await expectLater(
        client.submitFeatureRequest(
          const FeatureRequestDraft(title: 'Dark mode', description: 'Please add dark mode.'),
          userToken: 'tok_user_1',
        ),
        throwsA(
          isA<SubmissionQuotaException>()
              .having((e) => e.reason, 'reason',
                  SubmissionQuotaReason.subscriptionInactive)
              .having((e) => e.code, 'code', 'subscription_inactive')
              .having((e) => e.status, 'status', 402),
        ),
      );
    });

    test('unknown or missing code falls back to quota-exceeded reason',
        () async {
      final cases = <String, Object?>{
        'missing code': <String, dynamic>{'error': 'Payment required'},
        'unknown code': <String, dynamic>{
          'error': 'Payment required',
          'code': 'mystery_code',
        },
      };
      for (final entry in cases.entries) {
        final client = _clientReturning(
          () => _jsonResponse(entry.value as Map<String, dynamic>, 402),
        );

        await expectLater(
          client.submitFeatureRequest(
            const FeatureRequestDraft(title: 'Dark mode', description: 'Please add dark mode.'),
            userToken: 'tok_user_1',
          ),
          throwsA(
            isA<SubmissionQuotaException>().having(
              (e) => e.reason,
              'reason',
              SubmissionQuotaReason.tierLimitSubmissions,
            ),
          ),
          reason: entry.key,
        );
      }
    });

    test('a non-quota code is preserved verbatim for host diagnostics',
        () async {
      final client = _clientReturning(() => _jsonResponse(
            {'error': 'Payment required', 'code': 'mystery_code'},
            402,
          ));

      SubmissionQuotaException? caught;
      try {
        await client.submitFeatureRequest(
          const FeatureRequestDraft(title: 'Dark mode', description: 'Please add dark mode.'),
          userToken: 'tok_user_1',
        );
      } catch (e) {
        caught = e as SubmissionQuotaException;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, SubmissionQuotaReason.tierLimitSubmissions);
      expect(caught.code, 'mystery_code');
    });

    test('a 402 body without JSON falls back to the canonical code',
        () async {
      final client = _clientReturning(
        () => http.Response(
              'not json at all',
              402,
              headers: {'content-type': 'application/json'},
            ),
      );

      await expectLater(
        client.submitFeatureRequest(
          const FeatureRequestDraft(title: 'Dark mode', description: 'Please add dark mode.'),
          userToken: 'tok_user_1',
        ),
        throwsA(
          isA<SubmissionQuotaException>()
              .having((e) => e.reason, 'reason',
                  SubmissionQuotaReason.tierLimitSubmissions)
              .having((e) => e.code, 'code', 'tier_limit_submissions'),
        ),
      );
    });

    test('feedback intake endpoint surfaces the same typed quota error',
        () async {
      final client = _clientReturning(() => _jsonResponse(
            {
              'error': 'Monthly submission quota reached',
              'code': 'tier_limit_submissions',
            },
            402,
          ));

      await expectLater(
        client.submit(
          const FeedbackDraft(
            title: 'Broken thing',
            description: 'It broke badly.',
            platform: FeedbackPlatform.ios,
          ),
        ),
        throwsA(isA<SubmissionQuotaException>()),
      );
    });

    test('message and toString never embed the raw response body', () async {
      final client = _clientReturning(() => _jsonResponse(
            {
              'error': 'Monthly submission quota reached',
              'code': 'tier_limit_submissions',
              'internal': 'secret-upstream-detail',
            },
            402,
          ));

      SubmissionQuotaException? caught;
      try {
        await client.submitFeatureRequest(
          const FeatureRequestDraft(title: 'Dark mode', description: 'Please add dark mode.'),
          userToken: 'tok_user_1',
        );
      } catch (e) {
        caught = e as SubmissionQuotaException;
      }

      expect(caught, isNotNull);
      expect(caught!.responseBody, contains('secret-upstream-detail'));
      expect(caught.message, isNot(contains('secret-upstream-detail')));
      expect(caught.toString(), isNot(contains('secret-upstream-detail')));
    });

    test('other unexpected statuses still raise UnexpectedStatusException',
        () async {
      final client = _clientReturning(() => _jsonResponse({'error': 'boom'}, 500));

      await expectLater(
        client.submitFeatureRequest(
          const FeatureRequestDraft(title: 'Dark mode', description: 'Please add dark mode.'),
          userToken: 'tok_user_1',
        ),
        throwsA(isA<UnexpectedStatusException>()),
      );
    });
  });

  group('issue #15: localized strings cover the quota errors', () {
    const locales = [
      ('en', CupThreadStrings.en),
      ('zhHans', CupThreadStrings.zhHans),
      ('ja', CupThreadStrings.ja),
      ('fr', CupThreadStrings.fr),
      ('es', CupThreadStrings.es),
      ('de', CupThreadStrings.de),
      ('it', CupThreadStrings.it),
      ('pt', CupThreadStrings.pt),
      ('zhHant', CupThreadStrings.zhHant),
      ('ko', CupThreadStrings.ko),
      ('pl', CupThreadStrings.pl),
      ('no', CupThreadStrings.no),
      ('tr', CupThreadStrings.tr),
      ('vi', CupThreadStrings.vi),
    ];

    test('every locale defines non-empty quota error strings', () {
      for (final (name, s) in locales) {
        expect(s.submissionQuotaExceeded, isNotEmpty,
            reason: '$name submissionQuotaExceeded missing');
        expect(s.subscriptionInactive, isNotEmpty,
            reason: '$name subscriptionInactive missing');
      }
    });

    test('locales translate the quota strings instead of reusing English',
        () {
      for (final (name, s) in locales) {
        if (name == 'en') continue;
        expect(s.submissionQuotaExceeded,
            isNot(CupThreadStrings.en.submissionQuotaExceeded),
            reason: '$name submissionQuotaExceeded is untranslated');
        expect(s.subscriptionInactive,
            isNot(CupThreadStrings.en.subscriptionInactive),
            reason: '$name subscriptionInactive is untranslated');
      }
    });

    test('localizedErrorMessage maps quota reasons to the right string', () {
      const strings = CupThreadStrings.en;
      expect(
        strings.localizedErrorMessage(
            SubmissionQuotaException(
              reason: SubmissionQuotaReason.tierLimitSubmissions,
            )),
        strings.submissionQuotaExceeded,
      );
      expect(
        strings.localizedErrorMessage(
            SubmissionQuotaException(
              reason: SubmissionQuotaReason.subscriptionInactive,
            )),
        strings.subscriptionInactive,
      );
    });

    test('copyWith can override the quota strings', () {
      final custom = CupThreadStrings.en.copyWith(
        submissionQuotaExceeded: 'custom quota copy',
        subscriptionInactive: 'custom inactive copy',
      );
      expect(custom.submissionQuotaExceeded, 'custom quota copy');
      expect(custom.subscriptionInactive, 'custom inactive copy');
      expect(CupThreadStrings.en.submissionQuotaExceeded,
          isNot('custom quota copy'));
    });
  });

  group('issue #15: compose surfaces show the localized quota message', () {
    testWidgets(
        'FeatureRequestComposeSheet renders the quota message, not the generic error',
        (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/public/config/')) {
            return _jsonResponse({});
          }
          if (request.url.path == '/api/v1/feature-requests') {
            return _jsonResponse(
              {
                'error': 'Monthly submission quota reached',
                'code': 'tier_limit_submissions',
              },
              402,
            );
          }
          return _jsonResponse({'error': 'not found'}, 404);
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: CupThreadTheme(
          client: client,
          userToken: 'tok_user_1',
          child: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => FeatureRequestComposeSheet.show(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(0),
        'Dark mode please',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'A system-wide dark theme would be great.',
      );
      await tester.tap(find.text('Submit Request'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            'The monthly submission limit has been reached'),
        findsOneWidget,
      );
      expect(find.text('Something went wrong. Please try again.'),
          findsNothing);
    });

    testWidgets(
        'FeedbackComposer renders the inactive-subscription message, not the generic error',
        (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/public/config/')) {
            return _jsonResponse({});
          }
          if (request.url.path == '/api/v1/feedback') {
            return _jsonResponse(
              {
                'error': 'Workspace subscription is inactive',
                'code': 'subscription_inactive',
              },
              402,
            );
          }
          return _jsonResponse({'error': 'not found'}, 404);
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: CupThreadTheme(
          client: client,
          userToken: 'tok_user_1',
          child: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => FeedbackComposer.showModal(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(0),
        'Broken thing',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'It broke when I tapped the button.',
      );
      await tester.ensureVisible(find.text('Submit Feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Submissions are temporarily unavailable'),
        findsOneWidget,
      );
      expect(find.text('Something went wrong. Please try again.'),
          findsNothing);
    });
  });
}
