# CupThread Flutter SDK

Official Dart + Flutter SDK for cross-platform apps (iOS, Android, macOS, Windows, Linux, Web).

Part of the [CupThread.com](https://cupthread.com) platform.

## 🤖 Recommended: Install via AI Agent (Agentic Coding)

Instead of manually editing `pubspec.yaml` and wiring widgets by hand, install the official **CupThread Flutter AI Skill** into your workspace with [`npx skills`](https://github.com/skills-directory/skills) and let your AI assistant (Claude Code, Cursor, Copilot, Windsurf, Codex, Antigravity) integrate and customize it for you:

```sh
npx skills add CupThread/CupThreadAgenticCoding --skill cupthread-flutter-sdk
```

Once installed, simply copy and paste this prompt to your AI coding agent:

```text
Integrate the CupThread SDK (feedback, roadmap, and changelog screens) into this Flutter app. Scaffold a dedicated configuration helper with a placeholder for the App Key, and at the end, remind me with step-by-step instructions on how to set my App Key safely (e.g. via --dart-define or .env).
```

---

## CupThread Ecosystem
- 🌐 [CupThread.com](https://cupthread.com) — Feedback SaaS platform, developer console, and API.
- 🍏 [CupThread/CupThreadSwiftSDK](https://github.com/CupThread/CupThreadSwiftSDK) — Apple platform SDK (SwiftUI / SPM / XCFramework).
- 🤖 [CupThread/CupThreadAndroidSDK](https://github.com/CupThread/CupThreadAndroidSDK) — Android SDK (Jetpack Compose / Maven).
- ⚛️ [CupThread/CupThreadReactNativeSDK](https://github.com/CupThread/CupThreadReactNativeSDK) — React Native & Expo SDK (TypeScript).
- 💙 [CupThread/CupThreadFlutterSDK](https://github.com/CupThread/CupThreadFlutterSDK) — Flutter SDK (Dart).
- 🧠 [CupThread/CupThreadAgenticCoding](https://github.com/CupThread/CupThreadAgenticCoding) — AI-friendly CLI & Skills for pair programming.

---

## Manual Installation

### Option A: Via Git Dependency (Direct GitHub release)

In your `pubspec.yaml`:

```yaml
dependencies:
  cupthread_feedback:
    git:
      url: https://github.com/CupThread/CupThreadFlutterSDK.git
      ref: v0.1.0
```

### Option B: Via pub.dev (Once published)

Add `cupthread_feedback` to your `pubspec.yaml`:

```yaml
dependencies:
  cupthread_feedback: ^0.1.0
```

Or run:

```sh
flutter pub add cupthread_feedback
```

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  final client = FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_xxx', // from your CupThread Developer Console
    ),
  );

  runApp(
    CupThreadTheme(
      client: client,
      // Optional: set custom locale or string overrides (defaults to device locale or English)
      // locale: const Locale('zh', 'CN'),
      // strings: CupThreadStrings.zhHans,
      child: const MaterialApp(
        home: RoadmapBoardScreen(),
      ),
    ),
  );
}
```

---

## Ready-Made Flutter Widgets & Screens

Wrap your widget hierarchy in `CupThreadTheme(client: client)` to automatically inherit developer console appearance settings, color palette, localized strings, and anonymous user token.

- **`RoadmapBoardScreen()`**: Kanban roadmap board grouped by public columns with vote counts and stage badges.
- **`FeatureRequestsScreen()`**: Searchable feature requests list with optimistic upvoting, version filter chips, and creation sheet.
- **`FeatureRequestComposeSheet.show(context)`**: Dedicated sheet for proposing a new feature request (`POST /api/v1/feature-requests`).
- **`WhatsNewScreen()`**: Interactive release notes / changelog with Markdown formatting and email subscription.
- **`ChangelogOverlay.show(context, onlyIfUnseen: true)`**: In-app modal announcement sheet for the latest release notes with built-in "seen" persistence.
- **`FeedbackComposer()` / `FeedbackComposer.showModal(context, onPickAttachment: ...)`**: Structured feedback form with attachment uploads and host picker support.
- **`UserProfileView(userId: ...)`**: Public user/developer profile screen.

### Example: Presenting Latest Changelog on Launch (Only If Unseen)

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Only shows if the user hasn't seen this release yet, and automatically marks it seen
    ChangelogOverlay.show(context, onlyIfUnseen: true);
  });
}
```

### Example: Providing Attachment Picker to FeedbackComposer

```dart
FeedbackComposer.showModal(
  context,
  onPickAttachment: () async {
    // Pick image via image_picker or file_picker, then upload:
    // final bytes = await file.readAsBytes();
    // return await client.uploadAttachment(
    //   bytes: bytes,
    //   filename: file.name,
    //   mimeType: 'image/png',
    // );
    return null;
  },
);
```

---

## API Client Surface

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| `submit(draft, userToken?)` | `POST /api/v1/feedback` | Submit feedback draft with metadata and attachments |
| `uploadAttachment(...)` | `POST /api/v1/uploads/{images,r2}` | Upload screenshot or log attachment |
| `fetchAppConfig()` | `GET /api/v1/public/config/{appKey}` | Fetch app branding, appearance, and public settings |
| `fetchColumns()` | `GET /api/v1/public/columns/{appKey}` | Fetch Kanban board columns for roadmap |
| `fetchVersions()` | `GET /api/v1/public/versions/{appKey}` | Fetch release versions |
| `fetchFeatureRequests(...)` | `GET /api/v1/feature-requests` | List and search public feature requests |
| `submitFeatureRequest(draft, userToken)` | `POST /api/v1/feature-requests` | Propose a new feature request |
| `toggleVote(featureRequestId, userToken)` | `POST /api/v1/feature-requests/{id}/vote` | Upvote or remove upvote |
| `fetchComments(featureRequestId)` | `GET /api/v1/feature-requests/{id}/comments` | Fetch discussion comments |
| `postComment(featureRequestId, draft, userToken)` | `POST /api/v1/feature-requests/{id}/comments` | Post a comment or reply |
| `fetchChangelog()` | `GET /api/v1/public/apps/{appKey}/changelog` | Fetch published release notes |
| `subscribeToChangelog(email, userToken)` | `POST /api/v1/public/apps/{appKey}/changelog/subscribe` | Subscribe email to changelog |
| `unsubscribeFromChangelog(email)` | `POST /api/v1/public/apps/{appKey}/changelog/unsubscribe` | Unsubscribe email from changelog |
| `updateUserAttributes(...)` | `PUT /api/v1/public/apps/{appKey}/user` | Report user attributes (paying, plan, MRR) |
| `fetchUserProfile(userId)` | `GET /api/v1/users/{userId}/profile` | Fetch public user profile |

---

## Development & Testing

```sh
# Fetch dependencies
flutter pub get

# Run analysis
flutter analyze

# Run unit tests
flutter test
```

## License
MIT
