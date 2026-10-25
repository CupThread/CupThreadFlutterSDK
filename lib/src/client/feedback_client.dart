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

  /// Detects the intake endpoints' HTTP 402 Payment Required quota
  /// rejection and maps its `code` field to a typed exception
  /// (`tier_limit_submissions` / `subscription_inactive`). Returns null for
  /// any other status or an unparseable body, which callers surface as a
  /// generic unexpected-status error.
  static SubmissionQuotaException? _quotaRejection(
    int status,
    String responseBody,
  ) {
    if (status != 402) return null;
    String? code;
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is Map<String, dynamic>) {
        final c = parsed['code'];
        if (c is String && c.isNotEmpty) code = c;
      }
    } catch (_) {}
    return SubmissionQuotaException(
      reason: code == 'subscription_inactive'
          ? SubmissionQuotaReason.subscriptionInactive
          : SubmissionQuotaReason.tierLimitSubmissions,
      code: code,
      status: status,
      responseBody: responseBody,
    );
  }

  /// Resolves the Turnstile token to attach to an intake submission:
  /// draft-level token wins over the configured provider.
  Future<String?> _resolveTurnstileToken(String? explicit) async {    final trimmed = explicit?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final provider = config.turnstileTokenProvider;
    if (provider == null) return null;
    final token = (await provider())?.trim();
    if (token != null && token.isNotEmpty) return token;
    return null;
  }

  /// Submits user feedback draft.
  ///
  /// When [draft] carries session-uploaded attachments (attachment
  /// [FeedbackAttachment.uploadId] values) and no [userToken] is given, the
  /// SDK falls back to the shared [UserTokenStore] identity so the submission
  /// presents the same identity that created the upload sessions — the
  /// intake endpoint finalizes uploads only for their uploading identity
  /// (SEC-28) and would otherwise reject with `uploader_mismatch`.
  Future<FeedbackSubmissionResult> submit(
    FeedbackDraft draft, {
    String? userToken,
  }) async {
    final turnstileToken = await _resolveTurnstileToken(draft.turnstileToken);
    final hasSessionUploads = draft.attachments.any(
      (a) => a.uploadId != null && a.uploadId!.trim().isNotEmpty,
    );
    final identity = await _resolveIdentity(
      userToken,
      fallbackToStore: hasSessionUploads,
    );
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
      userToken: identity,
      acceptedStatuses: const [200, 201, 202],
    );

    return FeedbackSubmissionResult.fromJson(json);
  }

  /// Resolves the identity an intake or upload-session request presents as
  /// `X-User-Token`: [userToken] wins when non-blank. When it is blank and
  /// [fallbackToStore] is set, the shared [UserTokenStore] identity is used
  /// so upload sessions and the submissions referencing them keep one stable
  /// anonymous identity; without the flag the request stays fully anonymous.
  Future<String?> _resolveIdentity(
    String? userToken, {
    required bool fallbackToStore,
  }) async {
    final trimmed = userToken?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (!fallbackToStore) return null;
    return UserTokenStore.shared.getToken();
  }

  /// Uploads a binary file attachment through the governed upload-session
  /// flow.
  ///
  /// Two requests are made against [config.baseUrl]:
  ///
  /// 1. `POST /api/v1/uploads/sessions` pre-allocates one file slot bound to
  ///    the caller's identity. Anonymous callers must present an identity —
  ///    [userToken] when given, the shared [UserTokenStore] identity
  ///    otherwise — and an app-required Turnstile token is resolved through
  ///    `FeedbackClientConfig.turnstileTokenProvider` (the session endpoint
  ///    shares the feedback challenge binding).
  /// 2. `PUT /api/v1/uploads/{uploadId}` streams the bytes into the slot,
  ///    authorized by the session's bearer token.
  ///
  /// The returned [FeedbackAttachment] carries the slot's
  /// [FeedbackAttachment.uploadId]; pass the attachment (or its draft) to
  /// [submit] and the submission references the stored file through the
  /// top-level `uploadIds` array. The legacy direct endpoints are retired:
  /// `POST /api/v1/uploads/images` no longer returns a `key`/`url`, and
  /// `POST /api/v1/uploads/r2` is a 410 Gone tombstone — image and
  /// non-image files alike go through the session flow, and the storage
  /// [AttachmentKind] is derived from the file's MIME type.
  ///
  /// [maxBytes] (or `PublicAppConfig.maxAttachmentBytes` when cached) is
  /// enforced before any request; the session's per-file limit is enforced
  /// before the bytes are streamed, and an HTTP 413 rejection maps to
  /// [AttachmentTooLargeException]. An upload response that references no
  /// `uploadId` throws [InvalidResponseException] instead of constructing an
  /// attachment that could never be attached to a submission.
  ///
  /// [preferredKind] is ignored — it selected between the two retired direct
  /// endpoints and is kept only for source compatibility.
  Future<FeedbackAttachment> uploadAttachment({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    @Deprecated(
      'Upload sessions derive the storage kind from the MIME type; the parameter no longer selects a backend.',
    )
    AttachmentKind? preferredKind,
    int? maxBytes,
    String? userToken,
    Duration? timeout,
  }) async {
    final effectiveMax = maxBytes ?? _cachedAppConfig?.maxAttachmentBytes;
    if (effectiveMax != null && bytes.length > effectiveMax) {
      throw AttachmentTooLargeException(bytes.length, effectiveMax);
    }

    final effectiveTimeout = timeout ?? config.uploadTimeout;
    final turnstileToken = await _resolveTurnstileToken(null);
    // Upload sessions are always bound to an uploader identity; fall back to
    // the shared store so anonymous flows keep a stable identity across
    // session creation and the finalizing submission.
    final identity = (await _resolveIdentity(userToken, fallbackToStore: true))!;

    try {
      final session = await _createUploadSession(
        filename: filename,
        mimeType: mimeType,
        sizeBytes: bytes.length,
        identity: identity,
        turnstileToken: turnstileToken,
        timeout: effectiveTimeout,
      );

      final slotLimit = session.slot.maxSizeBytes;
      final sessionLimit = session.maxFileSizeBytes;
      final sessionMax = slotLimit != null && sessionLimit != null
          ? (slotLimit < sessionLimit ? slotLimit : sessionLimit)
          : (slotLimit ?? sessionLimit);
      if (sessionMax != null && bytes.length > sessionMax) {
        throw AttachmentTooLargeException(bytes.length, sessionMax);
      }

      return await _uploadToSlot(
        session,
        bytes,
        filename,
        mimeType,
        effectiveTimeout,
      );
    } catch (e) {
      if (e is FeedbackException) rethrow;
      if (e is TimeoutException) {
        throw InvalidResponseException(
          'Upload timed out requesting ${config.baseUrl}',
          e,
        );
      }
      throw UnreadableUploadResponseException(e.toString());
    }
  }

  /// Creates a one-file upload session and returns its bearer token plus the
  /// pre-allocated slot. A response missing `sessionToken` or the slot
  /// `uploadId` is an [InvalidResponseException] — continuing without them
  /// could only orphan the bytes.
  Future<_UploadSession> _createUploadSession({
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required String identity,
    String? turnstileToken,
    required Duration timeout,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: '/api/v1/uploads/sessions',
      body: {
        'appKey': config.appKey,
        'purpose': 'feedback_attachment',
        if (turnstileToken != null && turnstileToken.isNotEmpty)
          'turnstileToken': turnstileToken,
        'files': [
          {
            'clientFileId': 'file-1',
            'filename': filename,
            'contentType': mimeType,
            'sizeBytes': sizeBytes,
          },
        ],
      },
      userToken: identity,
      acceptedStatuses: const [200, 201],
      timeout: timeout,
    );

    final sessionJson = json['session'] as Map<String, dynamic>?;
    final sessionToken = (sessionJson?['sessionToken'] as String?)?.trim() ?? '';
    if (sessionToken.isEmpty) {
      throw const InvalidResponseException(
        'Upload session response is missing sessionToken',
      );
    }
    final files = json['files'] as List<dynamic>? ?? const [];
    if (files.isEmpty || files.first is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Upload session response allocated no file slot',
      );
    }
    final slotJson = files.first as Map<String, dynamic>;
    final uploadId = (slotJson['uploadId'] as String?)?.trim() ?? '';
    if (uploadId.isEmpty) {
      throw const InvalidResponseException(
        'Upload session file slot is missing uploadId',
      );
    }
    return _UploadSession(
      sessionToken: sessionToken,
      maxFileSizeBytes: (sessionJson?['maxFileSizeBytes'] as num?)?.toInt(),
      slot: _UploadSessionSlot(
        uploadId: uploadId,
        maxSizeBytes: (slotJson['maxSizeBytes'] as num?)?.toInt(),
      ),
    );
  }

  /// Streams the file bytes into the session slot via
  /// `PUT /api/v1/uploads/{uploadId}` and maps the `UploadedFileResponse`
  /// onto a [FeedbackAttachment], falling back to slot/local facts for
  /// anything the server omits.
  Future<FeedbackAttachment> _uploadToSlot(
    _UploadSession session,
    List<int> bytes,
    String filename,
    String mimeType,
    Duration timeout,
  ) async {
    final uri = Uri.parse(
      '${config.baseUrl}/api/v1/uploads/${Uri.encodeComponent(session.slot.uploadId)}',
    );
    try {
      final response = await _httpClient
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer ${session.sessionToken}',
              'Content-Type': mimeType,
            },
            body: bytes,
          )
          .timeout(timeout);

      if (response.statusCode == 401) {
        throw const AuthenticationRequiredException();
      }
      if (_isTurnstileChallenge(response.statusCode, response.body)) {
        throw TurnstileRequiredException(response.statusCode, response.body);
      }
      if (response.statusCode == 413) {
        final limit = session.slot.maxSizeBytes ?? session.maxFileSizeBytes;
        throw AttachmentTooLargeException(bytes.length, limit ?? bytes.length);
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw UnexpectedStatusException(response.statusCode, response.body);
      }

      final json = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      final uploadId = (json['uploadId'] as String?)?.trim() ?? '';
      final resolvedUploadId =
          uploadId.isNotEmpty ? uploadId : session.slot.uploadId;
      if (resolvedUploadId.isEmpty) {
        throw const InvalidResponseException(
          'Upload response references no uploadId; the stored file could not '
          'be attached to a submission',
        );
      }
      final responseMime = (json['contentType'] as String?)?.trim() ?? '';
      final resolvedMime = responseMime.isNotEmpty ? responseMime : mimeType;

      // key/url deliberately stay empty: the stored attachment is reachable
      // only through the authorized download endpoint, and the submission
      // must reference it by uploadId alone.
      return FeedbackAttachment(
        kind: resolvedMime.startsWith('image/')
            ? AttachmentKind.image
            : AttachmentKind.r2,
        uploadId: resolvedUploadId,
        filename: (json['filename'] as String?)?.trim().isNotEmpty == true
            ? json['filename'] as String
            : filename,
        mimeType: resolvedMime,
        size: (json['sizeBytes'] as num?)?.toInt() ?? bytes.length,
      );
    } on FeedbackException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on FormatException catch (e) {
      throw InvalidResponseException(
        'Failed to parse JSON response from $uri',
        e,
      );
    }
  }

  /// Fetches public app configuration.
  ///
  /// The config endpoint returns HTTP 404 (with an "App not found" body)
  /// for private apps (`allowPublic = false`) exactly as it does for
  /// unknown apps; it never returns a 200 body for a private app. A 404 is
  /// therefore surfaced as an [UnexpectedStatusException] with
  /// [UnexpectedStatusException.status] 404 and means "app not found or
  /// not public". Other non-200 outcomes have unrelated causes (401 →
  /// [AuthenticationRequiredException], 5xx → generic
  /// [UnexpectedStatusException], transport failures →
  /// [InvalidResponseException]) and callers should apply the same
  /// fail-closed handling to all of them rather than interpreting them as
  /// "not public".
  ///
  /// Failures never add to the cache, but they also do not evict an
  /// existing cached config: after a failed `forceRefresh: true` call, a
  /// subsequent default call returns the previously cached config without
  /// a network request.
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

  /// Maximum number of pages [fetchComments] will follow before giving up.
  ///
  /// Guards against a misbehaving server that keeps returning a non-advancing
  /// `nextCursor`, which would otherwise loop forever.
  static const int _commentsMaxPages = 100;

  /// Fetches a single page of discussion comments.
  ///
  /// Maps to `GET /api/v1/feature-requests/:id/comments` with the optional
  /// `limit` (1–200) and opaque `cursor` query parameters. The returned
  /// [FeatureRequestCommentPage] exposes `total`, `hasMore` and `nextCursor`;
  /// pass a previously returned cursor back in to walk through comments
  /// beyond the first page.
  ///
  /// To fetch everything at once, use [fetchComments].
  Future<FeatureRequestCommentPage> fetchCommentsPage(
    String featureRequestId, {
    int? limit,
    String? cursor,
  }) async {
    final params = <String, String>{};
    if (limit != null) {
      params['limit'] = limit.clamp(1, 200).toString();
    }
    if (cursor != null && cursor.isNotEmpty) {
      params['cursor'] = cursor;
    }
    final queryString = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final json = await _sendJson(
      method: 'GET',
      path: '/api/v1/feature-requests/$featureRequestId/comments$queryString',
    );
    return FeatureRequestCommentPage.fromJson(json);
  }

  /// Fetches all discussion comments on a feature request, in server order.
  ///
  /// Follows `hasMore` / `nextCursor` across pages so threads with more than
  /// one page still load completely. Stops early when the server fails to
  /// advance the cursor (null, unchanged, or already visited), and a page cap
  /// of [_commentsMaxPages] backstops anything else.
  Future<List<FeatureRequestComment>> fetchComments(String featureRequestId) async {
    final all = <FeatureRequestComment>[];
    final seenCursors = <String>{};
    String? cursor;
    var hasMore = true;
    for (var page = 0; hasMore && page < _commentsMaxPages; page++) {
      final result = await fetchCommentsPage(featureRequestId, cursor: cursor);
      final next = result.nextCursor;

      // While hasMore is true the server must hand back an advancing
      // cursor; a null, unchanged, or revisited cursor would return the
      // same page forever. Keep the first page's comments even then, but
      // drop a repeated page so its entries are not appended twice.
      final cannotAdvance = result.hasMore &&
          (next == null || next == cursor || seenCursors.contains(next));
      if (!cannotAdvance || cursor == null) {
        all.addAll(result.comments);
      }
      if (next != null) seenCursors.add(next);
      hasMore = result.hasMore;
      cursor = next;
      if (cannotAdvance) break;
    }
    return all;
  }

  /// Posts a comment on a feature request.
  ///
  /// The API authenticates comment writes with a **Clerk end-user session
  /// only**: the anonymous `X-User-Token` identity this SDK resolves from
  /// [FeedbackClientConfig] is not accepted and every call without a Clerk
  /// session is rejected with `401 authentication_required`
  /// ([AuthenticationRequiredException]). The bundled widgets hide the
  /// composer for anonymous sessions accordingly; calling this method
  /// directly requires the host to inject an `http.Client` whose requests
  /// carry the end user's Clerk session credentials.
  ///
  /// Author attribution ([CommentDraft.authorName] and friends) is resolved
  /// server-side from the signed-in profile: the server ignores the
  /// client-supplied author fields even though the draft still sends them.
  ///
  /// The server answers with the created comment wrapped in an envelope
  /// (`FeatureRequestCommentCreated`: `{ "comment": { … } }`), which this
  /// method unwraps. A flat comment object without a `comment` key is also
  /// accepted so hosts serving hand-written fixtures keep working.
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
    final envelope = json['comment'];
    final payload = envelope is Map<String, dynamic> ? envelope : json;
    return FeatureRequestComment.fromJson(payload);
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
  /// Calls that report any verified attribute ([isPaying], [plan], [mrr], or
  /// [currency]) must carry an HMAC-SHA256 signature produced with the app's
  /// SDK signing secret (cpt-user-attrs-v1).
  ///
  /// If [signature] is provided, it and [timestamp] are sent directly.
  /// [signature] must be accompanied by the [timestamp] the canonical string was
  /// computed over — omitting [timestamp] throws [ArgumentError], because the
  /// server verifies the signature against the timestamp sent in the request and
  /// a freshly generated one would never match.
  /// Otherwise, if a signing secret is configured in [signingSecret] or
  /// [FeedbackClientConfig.sdkSigningSecret], the SDK automatically signs the payload.
  /// Reporting a verified attribute without any configured secret throws
  /// [ArgumentError] before any network call — the API rejects unsigned
  /// payment attributes with `422 payment_attributes_require_signature`.
  /// Identity-only updates (none of [isPaying], [plan], [mrr], [currency])
  /// remain unsigned.
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

    final assertsPayment = body.containsKey('isPaying') ||
        body.containsKey('plan') ||
        body.containsKey('mrr') ||
        body.containsKey('currency');

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
      if (secret == null || secret.isEmpty) {
        throw ArgumentError(
          'sdkSigningSecret is required when reporting isPaying, plan, mrr, '
          'or currency; the API rejects unsigned payment attributes with '
          '422 payment_attributes_require_signature',
        );
      }
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
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${config.baseUrl}$path');
    final headers = <String, String>{};

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (userToken != null && userToken.isNotEmpty) {
      headers['X-User-Token'] = userToken;
    }

    final effectiveTimeout = timeout ?? config.requestTimeout;
    http.Response response;
    try {
      if (method == 'GET') {
        response = await _httpClient.get(uri, headers: headers).timeout(effectiveTimeout);
      } else if (method == 'POST') {
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(effectiveTimeout);
      } else if (method == 'PUT') {
        response = await _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(effectiveTimeout);
      } else if (method == 'DELETE') {
        response = await _httpClient.delete(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(effectiveTimeout);
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
      final quota = _quotaRejection(response.statusCode, response.body);
      if (quota != null) {
        throw quota;
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

/// One pre-allocated file slot of an upload session
/// (`CreateUploadSessionResponse.files[i]`).
class _UploadSessionSlot {
  final String uploadId;
  final int? maxSizeBytes;

  const _UploadSessionSlot({required this.uploadId, this.maxSizeBytes});
}

/// Parsed `POST /api/v1/uploads/sessions` response: the bearer token
/// authorizing `PUT /api/v1/uploads/{uploadId}` plus the pre-allocated slot.
class _UploadSession {
  final String sessionToken;
  final int? maxFileSizeBytes;
  final _UploadSessionSlot slot;

  const _UploadSession({
    required this.sessionToken,
    required this.slot,
    this.maxFileSizeBytes,
  });
}
