import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  group('CupThreadStrings', () {
    test('en provides valid default English strings', () {
      const strings = CupThreadStrings.en;
      expect(strings.featureRequests, 'Feature Requests');
      expect(strings.proposeFeature, 'Propose Feature');
      expect(strings.submitFeedback, 'Submit Feedback');
      expect(strings.whatsNew, "What's New");
      expect(strings.attachments, 'Attachments');
      expect(strings.anonymous, 'Anonymous');
    });

    test('zhHans provides valid Simplified Chinese strings', () {
      const strings = CupThreadStrings.zhHans;
      expect(strings.featureRequests, '功能建议');
      expect(strings.proposeFeature, '提交建议');
      expect(strings.submitFeedback, '提交反馈');
      expect(strings.whatsNew, '新版特性');
      expect(strings.attachments, '附件');
      expect(strings.anonymous, '匿名用户');
    });

    test('all locales define non-empty verificationRequired', () {
      final locales = [
        CupThreadStrings.en,
        CupThreadStrings.zhHans,
        CupThreadStrings.ja,
        CupThreadStrings.fr,
        CupThreadStrings.es,
        CupThreadStrings.de,
        CupThreadStrings.it,
        CupThreadStrings.pt,
        CupThreadStrings.zhHant,
        CupThreadStrings.ko,
        CupThreadStrings.pl,
        CupThreadStrings.no,
        CupThreadStrings.tr,
        CupThreadStrings.vi,
      ];
      for (final s in locales) {
        expect(s.verificationRequired, isNotEmpty);
      }
    });

    test('all locales define non-empty issue #6 keys', () {
      final locales = [
        CupThreadStrings.en,
        CupThreadStrings.zhHans,
        CupThreadStrings.ja,
        CupThreadStrings.fr,
        CupThreadStrings.es,
        CupThreadStrings.de,
        CupThreadStrings.it,
        CupThreadStrings.pt,
        CupThreadStrings.zhHant,
        CupThreadStrings.ko,
        CupThreadStrings.pl,
        CupThreadStrings.no,
        CupThreadStrings.tr,
        CupThreadStrings.vi,
      ];
      for (final s in locales) {
        expect(s.reply, isNotEmpty, reason: 'reply missing');
        expect(s.replyingTo, isNotEmpty, reason: 'replyingTo missing');
        expect(s.emailInvalid, isNotEmpty, reason: 'emailInvalid missing');
        expect(s.subscribedToUpdates, isNotEmpty,
            reason: 'subscribedToUpdates missing');
        expect(s.subscriptionFailed, isNotEmpty,
            reason: 'subscriptionFailed missing');
        expect(s.commentPostFailed, isNotEmpty,
            reason: 'commentPostFailed missing');
        expect(s.userNotFound, isNotEmpty, reason: 'userNotFound missing');
        expect(s.appsSection, isNotEmpty, reason: 'appsSection missing');
        expect(s.recentComments, isNotEmpty, reason: 'recentComments missing');
        expect(s.commentOn, isNotEmpty, reason: 'commentOn missing');
        expect(s.signInRequired, isNotEmpty, reason: 'signInRequired missing');
        expect(s.signInRequiredToVote, isNotEmpty,
            reason: 'signInRequiredToVote missing');
        expect(s.signInRequiredToSubmitFeedback, isNotEmpty,
            reason: 'signInRequiredToSubmitFeedback missing');
        expect(s.unexpectedError, isNotEmpty,
            reason: 'unexpectedError missing');
      }
    });

    test('all locales define non-empty issue #43 attachment keys', () {
      final locales = [
        CupThreadStrings.en,
        CupThreadStrings.zhHans,
        CupThreadStrings.ja,
        CupThreadStrings.fr,
        CupThreadStrings.es,
        CupThreadStrings.de,
        CupThreadStrings.it,
        CupThreadStrings.pt,
        CupThreadStrings.zhHant,
        CupThreadStrings.ko,
        CupThreadStrings.pl,
        CupThreadStrings.no,
        CupThreadStrings.tr,
        CupThreadStrings.vi,
      ];
      for (final s in locales) {
        expect(s.tooManyAttachments, isNotEmpty,
            reason: 'tooManyAttachments missing');
        expect(s.tooManyAttachments, isNot(equals(s.attachmentTooLarge)),
            reason: 'tooManyAttachments must be a distinct message');
      }
    });

    test('label templates keep their placeholders in every locale', () {
      final locales = [
        CupThreadStrings.en,
        CupThreadStrings.zhHans,
        CupThreadStrings.ja,
        CupThreadStrings.fr,
        CupThreadStrings.es,
        CupThreadStrings.de,
        CupThreadStrings.it,
        CupThreadStrings.pt,
        CupThreadStrings.zhHant,
        CupThreadStrings.ko,
        CupThreadStrings.pl,
        CupThreadStrings.no,
        CupThreadStrings.tr,
        CupThreadStrings.vi,
      ];
      for (final s in locales) {
        expect(s.replyingTo.contains('{name}'), isTrue,
            reason: 'replyingTo lost the {name} placeholder');
        expect(s.commentOn.contains('{title}'), isTrue,
            reason: 'commentOn lost the {title} placeholder');
      }
    });

    test('label helpers interpolate the placeholder values', () {
      const strings = CupThreadStrings.en;
      expect(strings.replyingToLabel('@Alice'), 'Replying to @Alice');
      expect(strings.commentOnLabel('Export CSV'), 'on Export CSV');
      const ja = CupThreadStrings.ja;
      expect(ja.replyingToLabel('太郎'), '太郎 に返信');
      expect(ja.commentOnLabel('CSV 書き出し'), 'CSV 書き出し について');
    });

    test('localizedErrorMessage maps known exceptions to short messages', () {
      const strings = CupThreadStrings.en;
      expect(
        strings.localizedErrorMessage(const TurnstileRequiredException()),
        strings.verificationRequired,
      );
      expect(
        strings
            .localizedErrorMessage(const AttachmentTooLargeException(200, 100)),
        strings.attachmentTooLarge,
      );
      expect(
        strings
            .localizedErrorMessage(const FeatureDisabledException('feedback')),
        strings.featureUnavailable,
      );
      expect(
        strings.localizedErrorMessage(const AuthenticationRequiredException()),
        strings.signInRequired,
      );
      // Raw errors (incl. UnexpectedStatusException with response bodies)
      // never leak to users.
      expect(
        strings.localizedErrorMessage(
            const UnexpectedStatusException(500, 'internal stack trace')),
        strings.unexpectedError,
      );
      expect(
        strings.localizedErrorMessage(Exception('random')),
        strings.unexpectedError,
      );
    });

    test('fromLocale maps locales correctly', () {
      expect(
        CupThreadStrings.fromLocale(const Locale('zh', 'CN')).featureRequests,
        '功能建议',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('zh', 'Hans')).featureRequests,
        '功能建议',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('ja', 'JP')).featureRequests,
        '機能リクエスト',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('fr', 'FR')).featureRequests,
        'Demandes de fonctionnalités',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('es', 'ES')).featureRequests,
        'Solicitudes de funciones',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('de', 'DE')).featureRequests,
        'Funktionswünsche',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('it', 'IT')).featureRequests,
        'Richieste di funzionalità',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('pt', 'BR')).featureRequests,
        'Solicitações de recursos',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('zh', 'TW')).featureRequests,
        '功能建議',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('zh', 'HK')).featureRequests,
        '功能建議',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('ko', 'KR')).featureRequests,
        '기능 요청',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('pl', 'PL')).featureRequests,
        'Propozycje funkcji',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('nb', 'NO')).featureRequests,
        'Funksjonsønsker',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('tr', 'TR')).featureRequests,
        'Özellik istekleri',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('vi', 'VN')).featureRequests,
        'Yêu cầu tính năng',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('en', 'US')).featureRequests,
        'Feature Requests',
      );
      expect(
        CupThreadStrings.fromLocale(const Locale('ru', 'RU')).featureRequests,
        'Feature Requests',
      );
      expect(
        CupThreadStrings.fromLocale(null).featureRequests,
        'Feature Requests',
      );
    });

    test('copyWith allows overriding specific strings', () {
      final custom = CupThreadStrings.en.copyWith(
        proposeFeature: 'Submit Your Idea',
      );
      expect(custom.proposeFeature, 'Submit Your Idea');
      expect(custom.featureRequests, 'Feature Requests');
    });

    testWidgets('CupThreadTheme provides localized strings to context',
        (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
      );

      late CupThreadStrings resolvedStrings;

      await tester.pumpWidget(
        CupThreadTheme(
          client: client,
          locale: const Locale('zh', 'CN'),
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                resolvedStrings = CupThreadTheme.stringsOf(ctx);
                return Text(resolvedStrings.proposeFeature);
              },
            ),
          ),
        ),
      );
      // One extra frame for CupThreadTheme to restore the anonymous
      // identity from storage before building its child.
      await tester.pump();

      expect(find.text('提交建议'), findsOneWidget);
      expect(resolvedStrings.submitFeedback, '提交反馈');
    });
  });
}
