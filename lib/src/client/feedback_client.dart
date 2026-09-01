import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/formatters.dart';
import 'feedback_exception.dart';

/// Configuration for FeedbackClient.
class FeedbackClientConfig {
  final String baseUrl;
  final String appKey;
  final FeedbackPlatform defaultPlatform;

  FeedbackClientConfig({
    required String baseUrl,
    required this.appKey,
    FeedbackPlatform? defaultPlatform,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        defaultPlatform = defaultPlatform ?? FeedbackPlatform.current;
}

/// Primary API client for CupThread platform.
class FeedbackClient {
  final FeedbackClientConfig config;
  final http.Client _httpClient;

  FeedbackClient(
    this.config, {
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Submits user feedback draft.
  Future<FeedbackSubmissionResult> submit(
    FeedbackDraft draft, {
    String? userToken,
  }) async {
    final payload = draft.toJson(
      appKey: config.appKey,
      submittedAt: iso8601Now(),
    );

    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/feedback',
      body: payload,
      userToken: userToken,
      acceptedStatuses: const [200, 201, 202],
    );

    return FeedbackSubmissionResult.fromJson(json);
  }

  /// Uploads binary file attachment.
  Future<FeedbackAttachment> uploadAttachment({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    AttachmentKind? preferredKind,
  }) async {
    final kind = preferredKind ??
        (mimeType.startsWith('image/') ? AttachmentKind.image : AttachmentKind.r2);
    final path = kind == AttachmentKind.image
        ? '/api/v1/uploads/images'
        : '/api/v1/uploads/r2';

    final uri = Uri.parse('${config.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    request.fields['appKey'] = config.appKey;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    try {
      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw UnexpectedStatusException(response.statusCode, response.body);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return FeedbackAttachment.fromJson(json);
    } catch (e) {
      if (e is FeedbackException) rethrow;
      throw UnreadableUploadResponseException(e.toString());
    }
  }

  /// Fetches public app configuration.
  Future<PublicAppConfig> fetchAppConfig() async {
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/public/config/${config.appKey}',
    );
    return PublicAppConfig.fromJson(json);
  }

  /// Fetches Kanban board columns.
  Future<List<BoardColumn>> fetchColumns() async {
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/public/columns/${config.appKey}',
    );
    final list = (json['columns'] as List<dynamic>? ?? [])
        .map((c) => BoardColumn.fromJson(c as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  /// Fetches release versions.
  Future<List<AppVersion>> fetchVersions() async {
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/public/versions/${config.appKey}',
    );
    final list = (json['versions'] as List<dynamic>? ?? [])
        .map((v) => AppVersion.fromJson(v as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  /// Fetches paged feature requests.
  Future<ListFeatureRequestsResult> fetchFeatureRequests({
    required String userToken,
    int limit = 50,
    int offset = 0,
    String? versionId,
    String? query,
  }) async {
    final params = <String, String>{
      'appKey': config.appKey,
      'userToken': userToken,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (versionId != null && versionId.isNotEmpty) {
      params['versionId'] = versionId;
    }
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }

    final queryString = Uri(queryParameters: params).query;
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/feature-requests?$queryString',
    );
    return ListFeatureRequestsResult.fromJson(json);
  }

  /// Proposes a new feature request.
  Future<FeatureRequestSubmissionResult> submitFeatureRequest(
    FeatureRequestDraft draft, {
    required String userToken,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/feature-requests',
      body: draft.toJson(appKey: config.appKey, requesterToken: userToken),
      acceptedStatuses: const [200, 201],
    );
    return FeatureRequestSubmissionResult.fromJson(json);
  }

  /// Toggles an upvote on a feature request.
  Future<VoteResult> toggleVote(
    String featureRequestId, {
    required String userToken,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/feature-requests/$featureRequestId/vote',
      body: {
        'appKey': config.appKey,
        'userToken': userToken,
      },
      acceptedStatuses: const [200],
    );
    return VoteResult.fromJson(json);
  }

  /// Fetches discussion comments.
  Future<List<FeatureRequestComment>> fetchComments(String featureRequestId) async {
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/feature-requests/$featureRequestId/comments',
    );
    return (json['comments'] as List<dynamic>? ?? [])
        .map((c) => FeatureRequestComment.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Posts a comment on a feature request.
  Future<FeatureRequestComment> postComment(
    String featureRequestId,
    CommentDraft draft, {
    required String userToken,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/feature-requests/$featureRequestId/comments',
      body: draft.toJson(),
      userToken: userToken,
      acceptedStatuses: const [200, 201],
    );
    return FeatureRequestComment.fromJson(json);
  }

  /// Fetches published changelog release notes.
  Future<List<ChangelogEntry>> fetchChangelog() async {
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/public/apps/${config.appKey}/changelog',
    );
    final list = (json['entries'] as List<dynamic>? ?? [])
        .map((e) => ChangelogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return list;
  }

  /// Loads newest release entries and appearance for the What's-New overlay.
  Future<({List<ChangelogEntry> entries, SdkAppearance appearance})?>
      prepareChangelogOverlay() async {
    final appConfig = await fetchAppConfig();
    if (!appConfig.sdk.features.changelog) return null;

    final limit = appConfig.sdk.changelogOverlay.clampedEntryCount;
    final all = await fetchChangelog();
    final entries = all.take(limit).toList();
    if (entries.isEmpty) return null;

    return (entries: entries, appearance: appConfig.sdk);
  }

  /// Subscribes an email to changelog notifications.
  Future<ChangelogSubscriptionResult> subscribeToChangelog(
    String email, {
    required String userToken,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/public/apps/${config.appKey}/changelog/subscribe',
      body: {'email': email.trim()},
      userToken: userToken,
      acceptedStatuses: const [200, 201],
    );
    return ChangelogSubscriptionResult.fromJson(json);
  }

  /// Unsubscribes an email from changelog notifications.
  Future<ChangelogUnsubscribeResult> unsubscribeFromChangelog(String email) async {
    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/public/apps/${config.appKey}/changelog/unsubscribe',
      body: {'email': email.trim()},
      acceptedStatuses: const [200],
    );
    return ChangelogUnsubscribeResult.fromJson(json);
  }

  /// Reports self-declared user attributes.
  Future<UserAttributesUpdateResult> updateUserAttributes({
    required String userToken,
    bool? isPaying,
    String? plan,
    double? mrr,
    String? currency,
  }) async {
    final body = <String, dynamic>{};
    if (isPaying != null) body['isPaying'] = isPaying;
    if (plan != null && plan.isNotEmpty) body['plan'] = plan.trim();
    if (mrr != null) body['mrr'] = mrr;
    if (currency != null && currency.isNotEmpty) body['currency'] = currency.trim();

    final json = await _sendJson(
      method: 'PUT',
      path: '/api/v1/public/apps/${config.appKey}/user',
      body: body,
      userToken: userToken,
      acceptedStatuses: const [200],
    );
    return UserAttributesUpdateResult.fromJson(json);
  }

  /// Fetches public user profile.
  Future<PublicUserProfileResult> fetchUserProfile(String userId) async {
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/users/$userId/profile',
    );
    return PublicUserProfileResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _sendJson({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? userToken,
    List<int> acceptedStatuses = const [200],
  }) async {
    final uri = Uri.parse('${config.baseUrl}$path');
    final headers = <String, String>{};

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (userToken != null && userToken.isNotEmpty) {
      headers['X-User-Token'] = userToken;
    }

    http.Response response;
    try {
      if (method == 'GET') {
        response = await _httpClient.get(uri, headers: headers);
      } else if (method == 'POST') {
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      } else if (method == 'PUT') {
        response = await _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      } else if (method == 'DELETE') {
        response = await _httpClient.delete(uri, headers: headers);
      } else {
        throw UnsupportedError('Unsupported HTTP method: $method');
      }
    } catch (e) {
      if (e is FeedbackException) rethrow;
      throw InvalidResponseException('Network failure requesting $uri', e);
    }

    if (!acceptedStatuses.contains(response.statusCode)) {
      if (response.statusCode == 401) {
        throw const AuthenticationRequiredException();
      }
      throw UnexpectedStatusException(response.statusCode, response.body);
    }

    if (response.body.isEmpty) {
      return {};
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw InvalidResponseException('Failed to parse JSON response from $uri', e);
    }
  }
}
