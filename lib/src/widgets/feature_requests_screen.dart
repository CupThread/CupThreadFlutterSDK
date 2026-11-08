import 'dart:async';

import 'package:flutter/material.dart';
import '../client/feedback_exception.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import 'avatar.dart';
import 'badge.dart';
import 'feature_request_compose_sheet.dart';
import 'feature_request_detail_sheet.dart';
import 'vote_button.dart';
import 'vote_turnstile.dart';

/// Screen displaying searchable feature requests board with filtering and creation modal.
class FeatureRequestsScreen extends StatefulWidget {
  final String? title;

  const FeatureRequestsScreen({
    super.key,
    this.title,
  });

  @override
  State<FeatureRequestsScreen> createState() => _FeatureRequestsScreenState();
}

class _FeatureRequestsScreenState extends State<FeatureRequestsScreen> {
  List<FeatureRequestItem> _items = [];
  List<AppVersion> _versions = [];
  String? _selectedVersionId;
  String _query = '';

  bool _isLoading = true;
  bool _isLoadingMore = false;
  Object? _loadError;
  int _total = 0;

  /// Raw rows consumed from the server so far (page row counts, including
  /// malformed elements the model skipped). Offset pagination advances by
  /// this, not by [_items.length], or a dropped element would misalign the
  /// offset and repeat the row right after it.
  int _rawOffset = 0;

  /// Opaque keyset cursor returned by the most recently applied page, or
  /// null when the server does not paginate with cursors (legacy offset
  /// mode) or said there is no next page. Non-null switches load-more to
  /// cursor pagination, whose pages stay stable when moderation approves,
  /// hides, or reorders rows between fetches.
  String? _nextCursor;

  /// Monotonically increasing token for in-flight list requests. A response
  /// is applied only while its captured generation still matches, so a slow
  /// refresh or append can never clobber newer results.
  int _requestGeneration = 0;

  /// Monotonically increasing token for the session identity the list rows
  /// were loaded under (`hasVoted`/`isOwnRequest` are identity-scoped).
  /// Unlike [_requestGeneration] — which every reload bumps, including
  /// same-session searches and filters — this advances only when the user
  /// token or anonymous status actually changes, so vote responses can
  /// distinguish "the row was re-refreshed" from "the row now belongs to a
  /// different session" and apply their session-scoped `voted` only in the
  /// former case.
  int _identityGeneration = 0;
  final Set<String> _votingIds = {};
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  PublicAppConfig? _lastConfig;
  String? _lastUserToken;
  bool? _lastIsAnonymous;
  bool _hasAttemptedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndLoad();
  }

  void _checkAndLoad() {
    final isConfigLoading = CupThreadTheme.isConfigLoading(context);
    final configError = CupThreadTheme.configErrorOf(context);
    final appConfig = CupThreadTheme.configOf(context);

    if (isConfigLoading && appConfig == null) return;

    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.featureRequests,
    );

    if (configError != null && appConfig == null && !isEnabled) return;
    if (!isEnabled) return;
    if (_isPlatformGated()) return;
    if (_isAnonymousViewGated()) return;

    final userToken = CupThreadTheme.userTokenOf(context);
    final isAnonymous = CupThreadTheme.isAnonymous(context);
    if (!_hasAttemptedLoad ||
        _lastConfig != appConfig ||
        _lastUserToken != userToken ||
        _lastIsAnonymous != isAnonymous) {
      // Bump only on a real identity change — a config-only refresh (new
      // config instance, same session) reloads the rows but must not
      // invalidate in-flight votes' right to apply their `voted`.
      if (_hasAttemptedLoad &&
          (_lastUserToken != userToken || _lastIsAnonymous != isAnonymous)) {
        _identityGeneration++;
      }
      _lastConfig = appConfig;
      _lastUserToken = userToken;
      _lastIsAnonymous = isAnonymous;
      _hasAttemptedLoad = true;
      // A session change (e.g. signing in after an authentication error)
      // must leave the stale error state, or the user stays trapped on
      // sign-in guidance whose Retry was hidden precisely because a retry
      // could not succeed under the old session.
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
      _loadData();
    }
  }

  /// Whether the anonymous roadmap-view policy gates this screen: with config
  /// resolved, anonymous sessions may not load the requests list at all.
  /// Mirrors `RoadmapBoardScreen._isAnonymousViewGated` — the requests screen
  /// consumes the same policy-gated endpoints (`GET /api/v1/feature-requests`
  /// and `GET /api/v1/public/versions/:appKey`) as the board, so without this
  /// gate anonymous users on sign-in-only boards land in a retry loop that
  /// can never succeed (every request answers 401).
  bool _isAnonymousViewGated({bool listen = true}) {
    final config = CupThreadTheme.configOf(context, listen: listen);
    return config != null &&
        !config.allowAnonymousRoadmap &&
        CupThreadTheme.isAnonymous(context);
  }

  /// Whether the server's `allowedPlatforms` policy gates this screen: with
  /// config resolved, the effective platform is not authorized to run the
  /// SDK at all. Mirrors `RoadmapBoardScreen._isPlatformGated` — every
  /// surface this screen offers (browse, vote, comment, propose) is
  /// unauthorized here, so no request can succeed under the policy.
  bool _isPlatformGated({bool listen = true}) {
    return !CupThreadTheme.isPlatformAllowed(context, listen: listen);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Async completion paths (sheet callbacks) can invoke this after dispose;
    // bail before any context lookups on a defunct element.
    if (!mounted) return;
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.featureRequests,
      listen: false,
    );
    if (!isEnabled) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (_isAnonymousViewGated(listen: false)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (_isPlatformGated(listen: false)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);
    final generation = ++_requestGeneration;

    try {
      final results = await Future.wait([
        client.fetchFeatureRequests(
          userToken: userToken,
          versionId: _selectedVersionId,
          query: _query.isNotEmpty ? _query : null,
        ),
        client.fetchVersions(),
      ]);

      final requestsRes = results[0] as ListFeatureRequestsResult;
      final versionsRes = results[1] as List<AppVersion>;

      if (mounted && generation == _requestGeneration) {
        setState(() {
          _items = requestsRes.requests;
          _total = requestsRes.total;
          _rawOffset = requestsRes.pageRowCount;
          _nextCursor = requestsRes.nextCursor;
          _versions = versionsRes;
          _isLoading = false;
          _isLoadingMore = false;
          _loadError = null;
          // A page request started while this refresh was pending captured
          // the same generation; invalidate it so its stale offset cannot
          // append pre-refresh items onto the replaced list.
          _requestGeneration++;
        });
      }
    } catch (e) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _isLoading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    // Same policy gate as the initial load: the paged endpoint is equally
    // gated, so do not send requests anonymous sessions cannot succeed.
    if (_isAnonymousViewGated(listen: false)) return;
    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);
    final generation = _requestGeneration;
    final sentCursor = _nextCursor;

    setState(() => _isLoadingMore = true);
    try {
      final res = await client.fetchFeatureRequests(
        userToken: userToken,
        versionId: _selectedVersionId,
        query: _query.isNotEmpty ? _query : null,
        offset: _rawOffset,
        // When the server mints cursors, follow the keyset page instead of
        // the legacy offset: cursor pages cannot skip or duplicate rows
        // when moderation reorders them between fetches. Sending both
        // parameters would be ambiguous, so the client omits `offset`
        // whenever a cursor is present.
        cursor: sentCursor,
      );
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _items = [..._items, ...res.requests];
          // Advance by the raw rows the server sent, not by the retained
          // items: the server skips rows by its own raw count. Kept in
          // step even while cursor-walking so a server without metadata
          // can fall back to the offset walk at any point.
          _rawOffset += res.pageRowCount;
          // An empty successful page means the server has no more rows even
          // if the reported total disagrees; stop paginating at what we have
          // or the same offset would be requested forever.
          _total = res.requests.isEmpty ? _rawOffset : res.total;
          // Follow the server's cursor, but never hop to the cursor we just
          // consumed — a server re-sending it would make every further tap
          // re-append the same page. An empty page ends cursor walking too.
          var next = res.nextCursor;
          if (res.requests.isEmpty || next == sentCursor) next = null;
          _nextCursor = next;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      // Keep the current page; the Load more row stays available to retry.
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _handleToggleVote(FeatureRequestItem target) async {
    if (target.isOwnRequest) return;
    if (_votingIds.contains(target.id)) return;
    if (!CupThreadTheme.isFeatureEnabled(context, (f) => f.featureRequests,
        listen: false)) {
      return;
    }
    final config = CupThreadTheme.configOf(context, listen: false);
    final isAnon = CupThreadTheme.isAnonymous(context);
    if (config != null && !config.allowAnonymousVote && isAnon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(CupThreadTheme.stringsOf(context).signInRequiredToVote)),
      );
      return;
    }

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);
    final generation = _requestGeneration;
    final identityGeneration = _identityGeneration;

    // Lock the row first so taps during a pending Turnstile preflight cannot
    // start overlapping verification or vote requests. The lock is released
    // on every exit path below.
    setState(() {
      _votingIds.add(target.id);
    });

    try {
      // Turnstile preflight: casting a new vote on an app that requires
      // anonymous-vote verification resolves the token before the optimistic
      // update, so a missing token never causes a doomed request followed by
      // a rollback flicker. Removing a vote is never verified.
      String? voteToken;
      if (voteNeedsTurnstilePreflight(config, isAnon, !target.hasVoted)) {
        voteToken = await resolveVoteTurnstileToken(context, client);
        if (!mounted || voteToken == null) return;
      }

      final nextVoted = !target.hasVoted;
      final nextCount = target.voteCount + (nextVoted ? 1 : -1);

      setState(() {
        _items = _items
            .map((i) => i.id == target.id
                ? i.copyWith(
                    hasVoted: nextVoted,
                    voteCount: nextCount < 0 ? 0 : nextCount)
                : i)
            .toList();
      });

      final res = target.hasVoted
          ? await client.removeVote(target.id, userToken: userToken)
          : await client.castVote(target.id,
              userToken: userToken, turnstileToken: voteToken);
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _items = _items
              .map((i) => i.id == target.id
                  ? i.copyWith(hasVoted: res.voted, voteCount: res.voteCount)
                  : i)
              .toList();
        });
      } else if (mounted) {
        // A refresh replaced the list while the vote was in flight. The
        // response's `voted` belongs to the session that cast the vote: it
        // still describes the reloaded rows when the refresh ran under the
        // same identity (a search or filter refresh — not a session
        // change), but must not overwrite them after a session change. The
        // identity generation separates the two; `voteCount` is global, so
        // the count reconciles either way.
        final sameIdentity = identityGeneration == _identityGeneration;
        setState(() {
          _items = _items
              .map((i) => i.id == target.id
                  ? i.copyWith(
                      hasVoted: sameIdentity ? res.voted : i.hasVoted,
                      voteCount: res.voteCount)
                  : i)
              .toList();
        });
      }
    } catch (_) {
      // Roll back only while no refresh replaced the list; a refreshed list
      // is newer server state than this vote's pre-vote snapshot.
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _items = _items.map((i) => i.id == target.id ? target : i).toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _votingIds.remove(target.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final strings = CupThreadTheme.stringsOf(context);
    final isConfigLoading = CupThreadTheme.isConfigLoading(context);
    final configError = CupThreadTheme.configErrorOf(context);
    final appConfig = CupThreadTheme.configOf(context);
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.featureRequests,
    );

    if (isConfigLoading && appConfig == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.featureRequests,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (configError != null && appConfig == null && !isEnabled) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.featureRequests,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  strings.configLoadFailed,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => CupThreadTheme.retryConfig(context),
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isEnabled) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.featureRequests,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 48, color: colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  strings.featureRequestsDisabled,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isPlatformGated()) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.featureRequests,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.devices, size: 48, color: colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  strings.platformUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isAnonymousViewGated()) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.featureRequests,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  strings.signInRequired,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text(
          widget.title ?? strings.featureRequests,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colors.primary),
            tooltip: strings.proposeFeature,
            onPressed: () =>
                FeatureRequestComposeSheet.show(context).then((res) {
              if (!mounted || res == null) return;
              _loadData();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  if (!mounted) return;
                  setState(() => _query = val.trim());
                  _loadData();
                });
              },
              decoration: InputDecoration(
                hintText: strings.searchFeatureRequests,
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: colors.textMuted),
                filled: true,
                fillColor: colors.inputBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.inputBorder),
                ),
              ),
            ),
          ),

          // Version chips
          if (_versions.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildVersionChip(null, strings.all, colors),
                  ..._versions
                      .map((v) => _buildVersionChip(v.id, v.label, colors)),
                ],
              ),
            ),

          // Requests list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : _loadError != null
                    ? _buildLoadError(colors, strings)
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  strings.noFeatureRequestsFound,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  strings.beTheFirstToSuggest,
                                  style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      FeatureRequestComposeSheet.show(context)
                                          .then((res) {
                                    if (!mounted || res == null) return;
                                    _loadData();
                                  }),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(strings.proposeAnIdea),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.primary,
                                    foregroundColor: colors.primaryText,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: colors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length + (_hasMore ? 1 : 0),
                              itemBuilder: (ctx, idx) => idx < _items.length
                                  ? _buildRequestCard(_items[idx], colors)
                                  : _buildLoadMoreRow(colors, strings),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Whether more pages can be loaded.
  ///
  /// A non-null [_nextCursor] means the server itself said there is a next
  /// page and handed us the keyset hop, which outranks the legacy
  /// `offset < total` heuristic — the reported total can disagree with the
  /// keyset position when rows are moderated between pages. Otherwise fall
  /// back to the legacy offset comparison.
  bool get _hasMore => _nextCursor != null || _rawOffset < _total;

  Widget _buildLoadError(CupThreadColors colors, CupThreadStrings strings) {
    // Covers the window where config has not resolved yet but the gated API
    // already answered 401: show sign-in guidance instead of a generic
    // failure whose Retry button could never succeed.
    final isAuthError = _loadError is AuthenticationRequiredException;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAuthError ? Icons.lock_outline : Icons.cloud_off,
              size: 48,
              color: isAuthError
                  ? colors.textMuted
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              isAuthError ? strings.signInRequired : strings.failedToLoadRequests,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isAuthError) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadData();
                },
                child: Text(strings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreRow(CupThreadColors colors, CupThreadStrings strings) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Center(
        child: _isLoadingMore
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.primary),
              )
            : TextButton(
                onPressed: _loadMore,
                child: Text(
                  strings.loadMore,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildVersionChip(String? id, String label, CupThreadColors colors) {
    final isSelected = _selectedVersionId == id;
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedVersionId = id);
          _loadData();
        },
        backgroundColor: colors.chipBg,
        selectedColor: colors.primary,
        labelStyle: TextStyle(
          color: isSelected ? colors.primaryText : colors.chipText,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRequestCard(FeatureRequestItem item, CupThreadColors colors) {
    // Capture both generations when this card is built: the card is rebuilt
    // after every reload, so the sheet callback below always compares its
    // vote against the reload state and the session identity it was opened
    // under.
    final generation = _requestGeneration;
    final identityGeneration = _identityGeneration;
    return Card(
      color: colors.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => FeatureRequestDetailSheet.show(
          context,
          item: item,
          onVoteEvent: (kind, updated) {
            if (!mounted) return;
            final isSameGeneration = generation == _requestGeneration;
            setState(() {
              _items = _items.map((i) {
                if (i.id != updated.id) return i;
                if (isSameGeneration) return updated;
                // A reload replaced the list while the sheet's vote was in
                // flight. Only the confirmed event carries server truth:
                // the optimistic and rollback items are projections of the
                // sheet-open snapshot, and the reloaded row never carried
                // them — reconciling their counts would overwrite the
                // reloaded count with a stale pre-vote value. The confirmed
                // item's `voted` belongs to the session that cast the vote:
                // apply it only when the reload ran under the same identity
                // (the identity generation, not the request generation —
                // same-session searches and filters reload without changing
                // whose `hasVoted` the rows carry), while the global
                // voteCount reconciles either way. Mirrors
                // _handleToggleVote.
                if (kind != FeatureRequestVoteEventKind.confirmed) return i;
                return identityGeneration == _identityGeneration
                    ? updated
                    : i.copyWith(voteCount: updated.voteCount);
              }).toList();
            });
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          children: [
                            if (item.columnName != null)
                              BadgeChip(
                                label: item.columnName!,
                                colorHex: item.columnColor,
                              ),
                            if (item.versionLabel != null)
                              BadgeChip(
                                label: 'v${item.versionLabel}',
                                isOutline: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  VoteButton(
                    voteCount: item.voteCount,
                    hasVoted: item.hasVoted,
                    onPress: () => _handleToggleVote(item),
                    disabled: item.isOwnRequest || _votingIds.contains(item.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.3,
                ),
              ),
              if (item.recentCommenters.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    ...item.recentCommenters.take(3).map(
                          (c) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            child: Avatar(
                                url: c.avatarUrl, name: c.authorName, size: 18),
                          ),
                        ),
                    if (item.hasMoreCommenters)
                      Text(
                        '+more',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
