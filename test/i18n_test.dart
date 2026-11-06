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

    test(
        'all 13 non-English locales translate issue #64 policy and kill-switch strings',
        () {
      final nonEnglishLocales = <(String, CupThreadStrings)>[
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

      const english = CupThreadStrings.en;
      final getters = <(String, String Function(CupThreadStrings))>[
        ('featureUnavailable', (s) => s.featureUnavailable),
        ('featureRequestsDisabled', (s) => s.featureRequestsDisabled),
        ('roadmapDisabled', (s) => s.roadmapDisabled),
        ('feedbackDisabled', (s) => s.feedbackDisabled),
        ('changelogDisabled', (s) => s.changelogDisabled),
        ('configLoadFailed', (s) => s.configLoadFailed),
        ('attachmentTooLarge', (s) => s.attachmentTooLarge),
      ];

      for (final (name, locale) in nonEnglishLocales) {
        for (final (key, getter) in getters) {
          final translated = getter(locale);
          final enValue = getter(english);
          expect(translated, isNotEmpty,
              reason: '$name.$key must not be empty');
          expect(translated, isNot(equals(enValue)),
              reason:
                  '$name.$key must not fall back to English default ("$enValue")');
        }
      }
    });

    test('every built-in locale defines every UI string', () {
      final locales = <(String, CupThreadStrings)>[
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

      // Exhaustive list of `final String` fields on CupThreadStrings. Field
      // renames break this test at compile time, so the audit cannot silently
      // stop covering a newly added string.
      final fields = <(String, String Function(CupThreadStrings))>[
        ('retry', (s) => s.retry),
        ('cancel', (s) => s.cancel),
        ('close', (s) => s.close),
        ('anonymous', (s) => s.anonymous),
        ('justNow', (s) => s.justNow),
        ('minutesAgoSuffix', (s) => s.minutesAgoSuffix),
        ('hoursAgoSuffix', (s) => s.hoursAgoSuffix),
        ('daysAgoSuffix', (s) => s.daysAgoSuffix),
        ('verificationRequired', (s) => s.verificationRequired),
        ('featureRequests', (s) => s.featureRequests),
        ('proposeFeature', (s) => s.proposeFeature),
        ('proposeAnIdea', (s) => s.proposeAnIdea),
        ('searchFeatureRequests', (s) => s.searchFeatureRequests),
        ('all', (s) => s.all),
        ('underReview', (s) => s.underReview),
        ('planned', (s) => s.planned),
        ('inProgress', (s) => s.inProgress),
        ('completed', (s) => s.completed),
        ('noFeatureRequestsFound', (s) => s.noFeatureRequestsFound),
        ('beTheFirstToSuggest', (s) => s.beTheFirstToSuggest),
        ('failedToLoadRequests', (s) => s.failedToLoadRequests),
        ('loadMore', (s) => s.loadMore),
        ('roadmap', (s) => s.roadmap),
        ('noItemsInColumn', (s) => s.noItemsInColumn),
        ('newFeatureRequest', (s) => s.newFeatureRequest),
        ('titleLabel', (s) => s.titleLabel),
        ('titleHint', (s) => s.titleHint),
        ('detailsLabel', (s) => s.detailsLabel),
        ('detailsHint', (s) => s.detailsHint),
        ('yourNameOptional', (s) => s.yourNameOptional),
        ('yourNameHint', (s) => s.yourNameHint),
        ('submitRequest', (s) => s.submitRequest),
        ('submitting', (s) => s.submitting),
        ('featureRequestSubmitted', (s) => s.featureRequestSubmitted),
        ('titleValidationMin3', (s) => s.titleValidationMin3),
        ('detailsValidationMin5', (s) => s.detailsValidationMin5),
        ('comments', (s) => s.comments),
        ('writeAComment', (s) => s.writeAComment),
        ('send', (s) => s.send),
        ('posting', (s) => s.posting),
        ('noCommentsYet', (s) => s.noCommentsYet),
        ('vote', (s) => s.vote),
        ('voted', (s) => s.voted),
        ('sendFeedback', (s) => s.sendFeedback),
        ('submitFeedback', (s) => s.submitFeedback),
        ('feedbackSummaryHint', (s) => s.feedbackSummaryHint),
        ('feedbackDetailsHint', (s) => s.feedbackDetailsHint),
        ('emailForRepliesOptional', (s) => s.emailForRepliesOptional),
        ('emailHint', (s) => s.emailHint),
        ('feedbackSent', (s) => s.feedbackSent),
        ('attachments', (s) => s.attachments),
        ('addAttachment', (s) => s.addAttachment),
        ('remove', (s) => s.remove),
        ('attachmentDefaultName', (s) => s.attachmentDefaultName),
        ('whatsNew', (s) => s.whatsNew),
        ('subscribeToUpdates', (s) => s.subscribeToUpdates),
        ('enterYourEmail', (s) => s.enterYourEmail),
        ('subscribe', (s) => s.subscribe),
        ('subscribed', (s) => s.subscribed),
        ('gotIt', (s) => s.gotIt),
        ('version', (s) => s.version),
        ('userProfile', (s) => s.userProfile),
        ('payingCustomer', (s) => s.payingCustomer),
        ('freeTier', (s) => s.freeTier),
        ('featureUnavailable', (s) => s.featureUnavailable),
        ('featureRequestsDisabled', (s) => s.featureRequestsDisabled),
        ('roadmapDisabled', (s) => s.roadmapDisabled),
        ('feedbackDisabled', (s) => s.feedbackDisabled),
        ('changelogDisabled', (s) => s.changelogDisabled),
        ('configLoadFailed', (s) => s.configLoadFailed),
        ('attachmentTooLarge', (s) => s.attachmentTooLarge),
        ('tooManyAttachments', (s) => s.tooManyAttachments),
        ('submissionQuotaExceeded', (s) => s.submissionQuotaExceeded),
        ('subscriptionInactive', (s) => s.subscriptionInactive),
        ('reply', (s) => s.reply),
        ('replyingTo', (s) => s.replyingTo),
        ('emailInvalid', (s) => s.emailInvalid),
        ('subscribedToUpdates', (s) => s.subscribedToUpdates),
        ('subscriptionFailed', (s) => s.subscriptionFailed),
        ('commentPostFailed', (s) => s.commentPostFailed),
        ('userNotFound', (s) => s.userNotFound),
        ('appsSection', (s) => s.appsSection),
        ('recentComments', (s) => s.recentComments),
        ('commentOn', (s) => s.commentOn),
        ('signInRequired', (s) => s.signInRequired),
        ('signInRequiredToVote', (s) => s.signInRequiredToVote),
        ('signInRequiredToComment', (s) => s.signInRequiredToComment),
        (
          'signInRequiredToSubmitFeedback',
          (s) => s.signInRequiredToSubmitFeedback
        ),
        ('unexpectedError', (s) => s.unexpectedError),
      ];

      for (final (name, locale) in locales) {
        for (final (key, getter) in fields) {
          expect(getter(locale).trim(), isNotEmpty,
              reason: '$name.$key must not be empty');
        }
      }
    });

    test('copyWith overrides issue #64 policy, error, and attachment keys', () {
      const base = CupThreadStrings.zhHans;
      final modified = base.copyWith(
        featureUnavailable: 'custom unavailable',
        featureRequestsDisabled: 'custom requests disabled',
        roadmapDisabled: 'custom roadmap disabled',
        feedbackDisabled: 'custom feedback disabled',
        changelogDisabled: 'custom changelog disabled',
        configLoadFailed: 'custom config load failed',
        attachmentTooLarge: 'custom attachment too large',
        tooManyAttachments: 'custom too many attachments',
      );

      expect(modified.featureUnavailable, 'custom unavailable');
      expect(modified.featureRequestsDisabled, 'custom requests disabled');
      expect(modified.roadmapDisabled, 'custom roadmap disabled');
      expect(modified.feedbackDisabled, 'custom feedback disabled');
      expect(modified.changelogDisabled, 'custom changelog disabled');
      expect(modified.configLoadFailed, 'custom config load failed');
      expect(modified.attachmentTooLarge, 'custom attachment too large');
      expect(modified.tooManyAttachments, 'custom too many attachments');

      // Assert non-overridden fields retain original base values
      expect(modified.proposeFeature, base.proposeFeature);
      expect(modified.featureRequests, base.featureRequests);
      expect(modified.submissionQuotaExceeded, base.submissionQuotaExceeded);
      expect(modified.retry, base.retry);
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
