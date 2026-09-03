import 'dart:convert';

import 'package:cupthread_feedback/cupthread_feedback.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Returns deterministic API responses for the screenshot demo.
http.Client createDemoHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;

    if (path.contains('/api/v1/public/config/')) {
      return _jsonResponse(_appConfig);
    }
    if (path.contains('/api/v1/public/columns/')) {
      return _jsonResponse(_columns);
    }
    if (path.contains('/api/v1/public/versions/')) {
      return _jsonResponse(_versions);
    }
    if (path.contains('/api/v1/feature-requests/')) {
      if (path.endsWith('/vote')) {
        return _jsonResponse({'voted': true, 'voteCount': 143});
      }
      if (path.endsWith('/comments')) {
        return _jsonResponse(_comments);
      }
    }
    if (path == '/api/v1/feature-requests') {
      if (request.method == 'POST') {
        return _jsonResponse(
          {'featureRequestId': 'req_demo_new', 'pending': false},
          statusCode: 201,
        );
      }
      return _jsonResponse(_featureRequests);
    }
    if (path.contains('/api/v1/public/apps/') && path.endsWith('/changelog')) {
      return _jsonResponse(_changelog);
    }
    if (path.contains('/api/v1/public/apps/') &&
        path.endsWith('/changelog/subscribe')) {
      return _jsonResponse({'subscribed': true, 'alreadySubscribed': false});
    }
    if (path.contains('/api/v1/feedback')) {
      return _jsonResponse(
        {'submissionId': 'sub_demo_123456'},
        statusCode: 201,
      );
    }

    return _jsonResponse({'error': 'Demo route not found'}, statusCode: 404);
  });
}

FeedbackDraft demoFeedbackDraft() {
  return FeedbackDraft(
    title: 'Export reports to CSV and PDF',
    description:
        'It would be super helpful to export weekly feedback analytics as CSV or PDF reports so we can share them with stakeholders.',
    reporterName: 'Alex Developer',
    reporterEmail: 'alex@example.com',
    platform: FeedbackPlatform.current,
    appVersion: '2.4.0',
    buildNumber: '240',
    attachments: const [
      FeedbackAttachment(
        kind: AttachmentKind.image,
        key: 'uploads/analytics_preview.png',
        url: 'https://example.com/uploads/analytics_preview.png',
        filename: 'analytics_preview.png',
        mimeType: 'image/png',
        size: 245760,
      ),
    ],
  );
}

http.Response _jsonResponse(
  Object body, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

const _appConfig = {
  'appId': 'app_demo_1',
  'appKey': 'app_sample_123',
  'slug': 'cupthread-demo',
  'name': 'CupThread Demo',
  'allowPublic': true,
  'allowedPlatforms': ['ios', 'universal'],
  'maxAttachmentBytes': 20000000,
  'allowAnonymousRoadmap': true,
  'allowAnonymousVote': true,
  'allowAnonymousFeedback': true,
  'allowAnonymousChangelog': true,
  'sdk': {
    'theme': 'light',
    'features': {
      'roadmap': true,
      'featureRequests': true,
      'changelog': true,
      'feedback': true,
    },
    'changelogOverlay': {
      'title': "What's New in v2.4",
      'subtitle': 'Discover the latest improvements and features in CupThread.',
      'primaryButton': 'Got It',
      'closeButton': 'Close',
      'entryCount': 2,
    },
  },
};

const _columns = {
  'columns': [
    {
      'id': 'col_planned',
      'appId': 'app_demo_1',
      'name': 'Planned',
      'slug': 'planned',
      'position': 1,
      'isVisible': true,
      'isSystem': false,
      'kind': 'normal',
      'color': '#8B5CF6',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 'col_progress',
      'appId': 'app_demo_1',
      'name': 'In Progress',
      'slug': 'in-progress',
      'position': 2,
      'isVisible': true,
      'isSystem': false,
      'kind': 'normal',
      'color': '#2563EB',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 'col_completed',
      'appId': 'app_demo_1',
      'name': 'Completed',
      'slug': 'completed',
      'position': 3,
      'isVisible': true,
      'isSystem': true,
      'kind': 'done',
      'color': '#16A34A',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    },
  ],
};

const _versions = {
  'versions': [
    {
      'id': 'ver_2_4_0',
      'appId': 'app_demo_1',
      'label': '2.4.0',
      'position': 1,
      'released': true,
      'releasedAt': '2026-08-20T10:00:00Z',
      'description': 'Liquid Glass design and performance improvements',
      'createdAt': '2026-08-01T00:00:00Z',
      'updatedAt': '2026-08-20T10:00:00Z',
    },
    {
      'id': 'ver_2_5_0',
      'appId': 'app_demo_1',
      'label': '2.5.0',
      'position': 2,
      'released': false,
      'description': 'Interactive widgets and offline synchronization',
      'createdAt': '2026-08-15T00:00:00Z',
      'updatedAt': '2026-08-15T00:00:00Z',
    },
  ],
};

const _featureRequests = {
  'requests': [
    {
      'id': 'req_1',
      'appId': 'app_demo_1',
      'title': 'Interactive Lock & Home Screen Widgets',
      'description':
          'Add Lock Screen widgets to track roadmap status and upvote features.',
      'status': 'in-progress',
      'columnId': 'col_progress',
      'columnSlug': 'in-progress',
      'columnName': 'In Progress',
      'columnColor': '#2563EB',
      'versionId': 'ver_2_5_0',
      'versionLabel': '2.5.0',
      'requesterName': 'Sarah Connor',
      'recentCommenters': [
        {'authorName': 'David Miller'},
        {'authorName': 'Elena Rostova'},
      ],
      'hasMoreCommenters': true,
      'approved': true,
      'voteCount': 142,
      'hasVoted': true,
      'isOwnRequest': false,
      'createdAt': '2026-08-15T08:30:00Z',
      'updatedAt': '2026-08-25T14:20:00Z',
    },
    {
      'id': 'req_2',
      'appId': 'app_demo_1',
      'title': 'Offline Draft Caching & Automatic Sync',
      'description':
          'Allow composing feedback offline with background synchronization once network is restored.',
      'status': 'in-progress',
      'columnId': 'col_progress',
      'columnSlug': 'in-progress',
      'columnName': 'In Progress',
      'columnColor': '#2563EB',
      'versionId': 'ver_2_5_0',
      'versionLabel': '2.5.0',
      'requesterName': 'David Miller',
      'recentCommenters': [
        {'authorName': 'Michael Scott'},
      ],
      'approved': true,
      'voteCount': 98,
      'hasVoted': false,
      'isOwnRequest': false,
      'createdAt': '2026-08-10T14:15:00Z',
      'updatedAt': '2026-08-22T09:10:00Z',
    },
    {
      'id': 'req_3',
      'appId': 'app_demo_1',
      'title': 'Export Feedback Threads to CSV & PDF',
      'description':
          'Allow exporting feedback threads with metadata to CSV and PDF for stakeholder reviews.',
      'status': 'completed',
      'columnId': 'col_completed',
      'columnSlug': 'completed',
      'columnName': 'Completed',
      'columnColor': '#16A34A',
      'versionId': 'ver_2_4_0',
      'versionLabel': '2.4.0',
      'releasedVersion': '2.4.0',
      'requesterName': 'Elena Rostova',
      'approved': true,
      'voteCount': 85,
      'hasVoted': false,
      'isOwnRequest': false,
      'createdAt': '2026-07-28T09:00:00Z',
      'updatedAt': '2026-08-20T10:00:00Z',
    },
    {
      'id': 'req_4',
      'appId': 'app_demo_1',
      'title': 'Apple Pencil & Scribble Annotation',
      'description':
          'Support drawing annotations on screenshots and handwriting inside composer.',
      'status': 'planned',
      'columnId': 'col_planned',
      'columnSlug': 'planned',
      'columnName': 'Planned',
      'columnColor': '#8B5CF6',
      'requesterName': 'Michael Scott',
      'approved': true,
      'voteCount': 64,
      'hasVoted': false,
      'isOwnRequest': false,
      'createdAt': '2026-08-01T11:20:00Z',
      'updatedAt': '2026-08-18T16:40:00Z',
    },
    {
      'id': 'req_5',
      'appId': 'app_demo_1',
      'title': 'Biometric Authentication for Admin Feedback',
      'description':
          'Require Face ID authentication before viewing or replying to confidential feedback categories.',
      'status': 'planned',
      'columnId': 'col_planned',
      'columnSlug': 'planned',
      'columnName': 'Planned',
      'columnColor': '#8B5CF6',
      'requesterName': 'Clara Oswald',
      'approved': true,
      'voteCount': 39,
      'hasVoted': false,
      'isOwnRequest': false,
      'createdAt': '2026-08-05T16:45:00Z',
      'updatedAt': '2026-08-19T11:05:00Z',
    },
  ],
  'total': 5,
};

const _changelog = {
  'entries': [
    {
      'id': 'chg_2_4_0',
      'title': 'Version 2.4.0 — Liquid Glass & Enhanced Export',
      'body': 'Welcome to **CupThread 2.4.0**! Refreshed visuals, faster search, and export tools.\n\n'
          '- **Export to CSV & PDF**: Export feedback threads directly from the app.\n'
          '- **Liquid Glass**: Refined native appearance across platforms.\n'
          '- **Instant Search**: Real-time search across all roadmap stages.',
      'versionLabel': '2.4.0',
      'publishedAt': '2026-08-20T10:00:00Z',
      'linkedRequests': [
        {'id': 'req_3', 'title': 'Export Feedback Threads to CSV & PDF'},
      ],
    },
    {
      'id': 'chg_2_3_0',
      'title': 'Version 2.3.0 — Attachments & Offline Support',
      'body': 'Rich attachment uploads and offline draft support are now available.\n\n'
          '- **Media Uploads**: Attach screenshots and diagnostic files.\n'
          '- **Offline Drafts**: Keep composing when connectivity is unavailable.',
      'versionLabel': '2.3.0',
      'publishedAt': '2026-07-15T09:30:00Z',
      'linkedRequests': [],
    },
  ],
};

const _comments = {
  'comments': [
    {
      'id': 'comment_1',
      'featureRequestId': 'req_1',
      'authorName': 'David Miller',
      'body': 'This would make roadmap updates much easier to discover.',
      'createdAt': '2026-08-24T12:00:00Z',
    },
  ],
};
