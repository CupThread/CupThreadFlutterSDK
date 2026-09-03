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

    testWidgets('CupThreadTheme provides localized strings to context', (tester) async {
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

      expect(find.text('提交建议'), findsOneWidget);
      expect(resolvedStrings.submitFeedback, '提交反馈');
    });
  });
}
