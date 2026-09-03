import 'package:flutter/material.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';
import 'demo_http_client.dart';

const _screenshotMode = bool.fromEnvironment('CUPTHREAD_SCREENSHOT_MODE');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Initialize client with App Key from CupThread Developer Console
    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_sample_123',
      ),
      httpClient: _screenshotMode ? createDemoHttpClient() : null,
    );

    // 2. Wrap your app in CupThreadTheme to inherit console colors and anonymous user token
    return CupThreadTheme(
      client: client,
      child: MaterialApp(
        title: 'CupThread Feedback Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2563EB),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('CupThread Flutter Demo'),
        backgroundColor: colors.card,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.view_kanban),
                label: const Text('Open Roadmap Board'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryText,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RoadmapBoardScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Browse Feature Requests'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryText,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FeatureRequestsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.newspaper),
                label: const Text("What's New / Changelog"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryText,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WhatsNewScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.feedback_outlined),
                label: const Text('Send Feedback'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  FeedbackComposer.showModal(
                    context,
                    initialDraft: demoFeedbackDraft(),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Show What's New Overlay"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => ChangelogOverlay.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
