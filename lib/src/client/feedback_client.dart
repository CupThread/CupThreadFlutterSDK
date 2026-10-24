import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/formatters.dart';
import 'feedback_exception.dart';
import 'sdk_attribute_signer.dart';
import 'user_token_store.dart';

/// Optional provider function resolving a Cloudflare Turnstile token.
typedef TurnstileTokenProvider = FutureOr<String?> Function();

/// Configuration for FeedbackClient.
class FeedbackClientConfig {
  final String baseUrl;
  final String appKey;

  /// Per-app secret used to HMAC-SHA256 sign end-user payment attributes
  /// (isPaying, mrr, plan) on `PUT /api/v1/public/apps/:appKey/user`.
  final String? sdkSigningSecret;

  final FeedbackPlatform defaultPlatform;
  final Duration requestTimeout;
  final Duration uploadTimeout;
  final TurnstileTokenProvider? turnstileTokenProvider;

  FeedbackClientConfig({
    required String baseUrl,
    required this.appKey,
    String? sdkSigningSecret,
    String? signingSecret,
    FeedbackPlatform? defaultPlatform,
    this.requestTimeout = const Duration(seconds: 15),
    this.uploadTimeout = const Duration(seconds: 60),
    this.turnstileTokenProvider,
  })  : sdkSigningSecret = sdkSigningSecret ?? signingSecret,
        baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        defaultPlatform = defaultPlatform ?? FeedbackPlatform.current;

  /// Alias for [sdkSigningSecret].
  String? get signingSecret => sdkSigningSecret;
}

/// Primary API client for CupThread platform.
class FeedbackClient {
  final FeedbackClientConfig config;
  final http.Client _httpClient;
  final TokenStorageAdapter? _storageOverride;
  PublicAppConfig? _cachedAppConfig;

  FeedbackClient(
    this.config, {
    http.Client? httpClient,
    TokenStorageAdapter? storage,
    PublicAppConfig? initialConfig,
  })  : _httpClient = httpClient ?? http.Client(),
        _storageOverride = storage,
        _cachedAppConfig = initialConfig;

  /// Storage used for durable client state (changelog seen versions).
  ///
  /// Defaults to the shared [UserTokenStore] adapter so "seen" state
  /// survives process restarts once the host configures persistence in one
  /// place via `UserTokenStore.configure(...)`. An explicit [storage]
  /// override always wins. Resolved lazily so a client constructed before
  /// `UserTokenStore.configure` still picks up the durable adapter.
  TokenStorageAdapter get _storage =>
      _storageOverride ?? UserTokenStore.shared.adapter;

  /// Returns cached app configuration if already fetched or provided, or null.
  PublicAppConfig? get cachedAppConfig => _cachedAppConfig;

  /// Detects the production API's Cloudflare Turnstile rejection on intake
  /// endpoints (HTTP 403 with turnstile code or error body).
  static bool _isTurnstileChallenge(int status, String responseBody) {
    if (status != 403) return false;
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is Map<String, dynamic>) {
        final code = parsed['code'];
        if (code is String && RegExp(r'turnstile', caseSensitive: false).hasMatch(code)) {
          return true;
        }
        final error = parsed['error'];
        if (error is String && RegExp(r'turnstile', caseSensitive: false).hasMatch(error)) {
          return true;
        }
      }
    } catch (_) {}
    return RegExp(r'turnstile', caseSensitive: false).hasMatch(responseBody);
  }

  /// Resolves the Turnstile token to attach to an intake submission:
  /// draft-level token wins over the configured provider.
  Future<String?> _resolveTurnstileToken(String? explicit) async {
    final trimmed = explicit?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final provider = config.turnstileTokenProvider;
    if (provider == null) return null;
    final token = (await provider())?.trim();
    if (token != null && token.isNotEmpty) return token;
    return null;
  }

  /// Submits user feedback draft.
  Future<FeedbackSubmissionResult> submit(
    FeedbackDraft draft, {
    String? userToken,
  }) async {
    final turnstileToken = await _resolveTurnstileToken(draft.turnstileToken);
    final payload = draft.toJson(
      appKey: config.appKey,
      submittedAt: iso8601Now(),
    );
    if (turnstileToken != null && turnstileToken.isNotEmpty) {
      payload['turnstileToken'] = turnstileToken;
    }

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
    int? maxBytes,
    String? userToken,
    Duration? timeout,
  }) async {
    final effectiveMax = maxBytes ?? _cachedAppConfig?.maxAttachmentBytes;
    if (effectiveMax != null && bytes.length > effectiveMax) {
      throw AttachmentTooLargeException(bytes.length, effectiveMax);
    }

    final kind = preferredKind ??
        (mimeType.startsWith('image/') ? AttachmentKind.image : AttachmentKind.r2);
    final path = kind == AttachmentKind.image
        ? '/api/v1/uploads/images'
        : '/api/v1/uploads/r2';

    final uri = Uri.parse('${config.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    request.fields['appKey'] = config.appKey;
    if (userToken != null && userToken.trim().isNotEmpty) {
      request.headers['X-User-Token'] = userToken.trim();
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    final effectiveTimeout = timeout ?? config.uploadTimeout;

    try {
      final streamedResponse = await _httpClient.send(request).timeout(effectiveTimeout);
      final response = await http.Response.fromStream(streamedResponse).timeout(effectiveTimeout);

      if (response.statusCode == 401) {
        throw const AuthenticationRequiredException();
      }
      if (_isTurnstileChallenge(response.statusCode, response.body)) {
        throw TurnstileRequiredException(response.statusCode, response.body);
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw UnexpectedStatusException(response.statusCode, response.body);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return FeedbackAttachment.fromJson(json);
    } catch (e) {
      if (e is FeedbackException) rethrow;
      if (e is TimeoutException) {
        throw InvalidResponseException('Upload timed out requesting $uri', e);
      }
      throw UnreadableUploadResponseException(e.toString());
    }
  }

  /// Fetches public app configuration.
  Future<PublicAppConfig> fetchAppConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAppConfig != null) {
      return _cachedAppConfig!;
    }
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/public/config/${config.appKey}',
    );
    final appConfig = PublicAppConfig.fromJson(json);
    _cachedAppConfig = appConfig;
    return appConfig;
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
      userToken: userToken,
    );
    return ListFeatureRequestsResult.fromJson(json);
  }

  /// Proposes a new feature request.
  Future<FeatureRequestSubmissionResult> submitFeatureRequest(
    FeatureRequestDraft draft, {
    required String userToken,
  }) async {
    final turnstileToken = await _resolveTurnstileToken(draft.turnstileToken);
    final body = draft.toJson(appKey: config.appKey, requesterToken: userToken);
    if (turnstileToken != null && turnstileToken.isNotEmpty) {
      body['turnstileToken'] = turnstileToken;
    }

    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/feature-requests',
      body: body,
      userToken: userToken,
      acceptedStatuses: const [200, 201],
    );
    return FeatureRequestSubmissionResult.fromJson(json);
  }

  /// Casts an upvote on a feature request.
  ///
  /// The endpoint (`POST /api/v1/feature-requests/:id/vote`) is insert-only and
  /// idempotent: repeating the request leaves an existing vote in place.
  /// To remove a vote, use [removeVote].
  Future<VoteResult> castVote(
    String featureRequestId, {
    required String userToken,
    String? shipNotifyEmail,
  }) async {
    final body = <String, dynamic>{
      'appKey': config.appKey,
      'userToken': userToken,
    };
    final trimmedEmail = shipNotifyEmail?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      body['shipNotifyEmail'] = trimmedEmail;
    }

    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/feature-requests/$featureRequestId/vote',
      body: body,
      userToken: userToken,
      acceptedStatuses: const [200],
    );
    return VoteResult.fromJson(json);
  }

  /// Removes the current user's upvote on a feature request.
  ///
  /// The endpoint (`DELETE /api/v1/feature-requests/:id/vote`) is idempotent:
  /// removing a vote that is not present returns `{ "voted": false, "voteCount": <n> }`
  /// with HTTP 200 rather than an error.
  Future<VoteResult> removeVote(
    String featureRequestId, {
    required String userToken,
  }) async {
    final json = await _sendJson(
      method: 'DELETE',
      path: '/api/v1/feature-requests/$featureRequestId/vote',
      body: {
        'appKey': config.appKey,
        'userToken': userToken,
      },
      userToken: userToken,
      acceptedStatuses: const [200],
    );
    return VoteResult.fromJson(json);
  }

  /// Casts a vote on a feature request (legacy compatibility wrapper).
  ///
  /// The backend vote endpoint (`POST /api/v1/feature-requests/:id/vote`) is
  /// now insert-only and no longer toggles. Use [castVote] to cast a vote and
  /// [removeVote] to remove a vote.
  @Deprecated(
    'Use castVote or removeVote instead. The backend vote endpoint is insert-only and no longer toggles.',
  )
  Future<VoteResult> toggleVote(
    String featureRequestId, {
    required String userToken,
    String? shipNotifyEmail,
  }) {
    return castVote(
      featureRequestId,
      userToken: userToken,
      shipNotifyEmail: shipNotifyEmail,
    );
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

  /// Maximum number of pages [fetchChangelog] will follow before giving up.
  ///
  /// Guards against a misbehaving server that keeps returning a non-advancing
  /// `nextCursor`, which would otherwise loop forever.
  static const int _changelogMaxPages = 100;

  /// Fetches a single page of published changelog release notes.
  ///
  /// Maps to `GET /api/v1/public/apps/:appKey/changelog` with the optional
  /// `limit` (1–100) and opaque `cursor` query parameters. The returned
  /// [ChangelogPage] exposes `hasMore` and `nextCursor`; pass a previously
  /// returned cursor back in to walk through entries beyond the newest 100.
  ///
  /// To fetch everything at once, use [fetchChangelog].
  Future<ChangelogPage> fetchChangelogPage({int? limit, String? cursor}) async {
    final params = <String, String>{};
    if (limit != null) {
      params['limit'] = limit.clamp(1, 100).toString();
    }
    if (cursor != null && cursor.isNotEmpty) {
      params['cursor'] = cursor;
    }
    final queryString = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/public/apps/${config.appKey}/changelog$queryString',
    );
    return ChangelogPage.fromJson(json);
  }

  /// Fetches all published changelog release notes, newest first.
  ///
  /// Follows `hasMore` / `nextCursor` across pages so apps with more than
  /// 100 published entries still see their full history. Stops early when
  /// the server fails to advance the cursor (null, unchanged, or already
  /// visited), and a page cap of [_changelogMaxPages] backstops anything else.
  Future<List<ChangelogEntry>> fetchChangelog() async {
    final all = <ChangelogEntry>[];
    final seenCursors = <String>{};
    String? cursor;
    var hasMore = true;
    for (var page = 0; hasMore && page < _changelogMaxPages; page++) {
      final result = await fetchChangelogPage(cursor: cursor);
      final next = result.nextCursor;

      // While hasMore is true the server must hand back an advancing
      // cursor; a null, unchanged, or revisited cursor would return the
      // same page forever. Keep the first page's entries even then, but
      // drop a repeated page so its entries are not appended twice.
      final cannotAdvance = result.hasMore &&
          (next == null || next == cursor || seenCursors.contains(next));
      if (!cannotAdvance || cursor == null) {
        all.addAll(result.entries);
      }
      if (next != null) seenCursors.add(next);
      hasMore = result.hasMore;
      cursor = next;
      if (cannotAdvance) break;
    }
    all.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return all;
  }

  /// Storage key for tracking seen changelog versions.
  String get _changelogSeenKey => 'cupthread_seen_changelog_${config.appKey}';

  /// Checks if a changelog version or entry ID has already been marked as seen.
  Future<bool> hasSeenChangelog(String version) async {
    try {
      final val = await _storage.getItem(_changelogSeenKey);
      if (val == null || val.isEmpty) return false;
      final seenVersions = val.split(',').map((s) => s.trim()).toSet();
      return seenVersions.contains(version.trim());
    } catch (_) {
      return false;
    }
  }

  /// Marks a changelog version or entry ID as seen.
  Future<void> markChangelogSeen(String version) async {
    try {
      final key = _changelogSeenKey;
      final val = await _storage.getItem(key);
      final seenVersions = val != null && val.isNotEmpty
          ? val.split(',').map((s) => s.trim()).toSet()
          : <String>{};
      seenVersions.add(version.trim());
      await _storage.setItem(key, seenVersions.join(','));
    } catch (_) {}
  }

  /// Loads newest release entries and appearance for the What's-New overlay.
  ///
  /// [isAnonymous] must reflect the caller's session state and is required so
  /// every call site states its anonymity explicitly: when true and the resolved
  /// config disables [PublicAppConfig.allowAnonymousChangelog], returns null
  /// before any changelog request is made.
  ///
  /// If [onlyIfUnseen] is true, returns null if the latest entry has already been marked seen.
  Future<({List<ChangelogEntry> entries, SdkAppearance appearance})?>
      prepareChangelogOverlay({
    bool onlyIfUnseen = false,
    required bool isAnonymous,
  }) async {
    try {
      final appConfig = await fetchAppConfig();
      if (!appConfig.sdk.features.changelog) return null;
      if (isAnonymous && !appConfig.allowAnonymousChangelog) return null;

      final limit = appConfig.sdk.changelogOverlay.clampedEntryCount;
      // The first page holds the newest entries, which is all the overlay
      // displays — fetching later pages would only add latency and one more
      // request that could fail and hide the overlay entirely.
      final page = await fetchChangelogPage(limit: limit);
      final entries = page.entries.toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      if (entries.isEmpty) return null;

      if (onlyIfUnseen) {
        final latest = entries.first;
        final versionKey = latest.versionLabel ?? latest.id;
        if (versionKey.isNotEmpty && await hasSeenChangelog(versionKey)) {
          return null;
        }
      }

      return (entries: entries, appearance: appConfig.sdk);
    } catch (_) {
      return null;
    }
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
  ///
  /// Calls that report payment attributes ([isPaying], [plan], or [mrr])
  /// must carry an HMAC-SHA256 signature produced with the app's SDK signing secret
  /// (cpt-user-attrs-v1).
  ///
  /// If [signature] is provided, it and [timestamp] are sent directly.
  /// [signature] must be accompanied by the [timestamp] the canonical string was
  /// computed over — omitting [timestamp] throws [ArgumentError], because the
  /// server verifies the signature against the timestamp sent in the request and
  /// a freshly generated one would never match.
  /// Otherwise, if a signing secret is configured in [signingSecret] or
  /// [FeedbackClientConfig.sdkSigningSecret], the SDK automatically signs the payload.
  /// Requests without payment attributes (identity or [currency] only) remain unsigned.
  Future<UserAttributesUpdateResult> updateUserAttributes({
    required String userToken,
    bool? isPaying,
    String? plan,
    double? mrr,
    String? currency,
    String? signingSecret,
    String? signature,
    int? timestamp,
  }) async {
    final body = <String, dynamic>{
      'userToken': userToken,
    };
    if (isPaying != null) body['isPaying'] = isPaying;
    if (plan != null && plan.isNotEmpty) body['plan'] = plan.trim();
    if (mrr != null) body['mrr'] = mrr;
    if (currency != null && currency.isNotEmpty) body['currency'] = currency.trim();

    final assertsPayment =
        body.containsKey('isPaying') || body.containsKey('plan') || body.containsKey('mrr');

    if (signature != null && signature.isNotEmpty) {
      if (timestamp == null) {
        throw ArgumentError(
          'timestamp is required when signature is provided; '
          'pass the timestamp your signature was computed over',
        );
      }
      body['signature'] = signature;
      body['timestamp'] = timestamp;
    } else if (assertsPayment) {
      final secret = signingSecret ?? config.sdkSigningSecret;
      if (secret != null && secret.isNotEmpty) {
        final ts =
            timestamp ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
        final sig = SdkAttributeSigner.sign(
          secret: secret,
          appKey: config.appKey,
          userToken: userToken,
          raw: body,
          timestamp: ts,
        );
        body['timestamp'] = ts;
        body['signature'] = sig;
      }
    }

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

    final timeout = config.requestTimeout;
    http.Response response;
    try {
      if (method == 'GET') {
        response = await _httpClient.get(uri, headers: headers).timeout(timeout);
      } else if (method == 'POST') {
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(timeout);
      } else if (method == 'PUT') {
        response = await _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(timeout);
      } else if (method == 'DELETE') {
        response = await _httpClient.delete(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(timeout);
      } else {
        throw UnsupportedError('Unsupported HTTP method: $method');
      }
    } catch (e) {
      if (e is FeedbackException) rethrow;
      if (e is TimeoutException) {
        throw InvalidResponseException('Request timed out requesting $uri', e);
      }
      throw InvalidResponseException('Network failure requesting $uri', e);
    }

    if (!acceptedStatuses.contains(response.statusCode)) {
      if (response.statusCode == 401) {
        throw const AuthenticationRequiredException();
      }
      if (_isTurnstileChallenge(response.statusCode, response.body)) {
        throw TurnstileRequiredException(response.statusCode, response.body);
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
