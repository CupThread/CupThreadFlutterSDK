import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import 'badge.dart';
import 'feature_request_detail_sheet.dart';
import 'vote_button.dart';
import 'vote_turnstile.dart';

/// Screen presenting the app's Kanban roadmap board grouped by stage columns.
class RoadmapBoardScreen extends StatefulWidget {
  final String? title;

  const RoadmapBoardScreen({
    super.key,
    this.title,
  });

  @override
  State<RoadmapBoardScreen> createState() => _RoadmapBoardScreenState();
}

class _RoadmapBoardScreenState extends State<RoadmapBoardScreen> {
  List<BoardColumn> _columns = [];
  List<FeatureRequestItem> _requests = [];
  String? _selectedColumnId;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Object? _loadError;
  int _total = 0;

  /// Raw rows consumed from the server so far (page row counts, including
  /// malformed elements the model skipped). Offset pagination advances by
  /// this, not by [_requests.length], or a dropped element would misalign
  /// the offset and repeat the row right after it.
  int _rawOffset = 0;

  /// Opaque keyset cursor returned by the most recently applied page, or
  /// null when the server does not paginate with cursors (legacy offset
  /// mode) or said there is no next page. Non-null switches load-more to
  /// cursor pagination, whose pages stay stable when moderation approves,
  /// hides, or reorders rows between fetches. Mirrors
  /// `FeatureRequestsScreen._nextCursor` — both screens consume the same
  /// paged endpoint.
  String? _nextCursor;

  /// Monotonically increasing token for in-flight board requests. A response
  /// is applied only while its captured generation still matches, so a stale
  /// page append can never follow a refresh that replaced the list.
  int _requestGeneration = 0;
  final Set<String> _votingIds = {};

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
      (f) => f.roadmap,
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
      _lastConfig = appConfig;
      _lastUserToken = userToken;
      _lastIsAnonymous = isAnonymous;
      _hasAttemptedLoad = true;
      // A session change (e.g. signing in after an authentication error)
      // must leave the stale error state, or the user stays trapped on
      // sign-in guidance whose Retry was hidden precisely because a retry
      // could not succeed under the old session. Mirrors
      // FeatureRequestsScreen._checkAndLoad — the board consumes the same
      // session-scoped rows (`hasVoted`, `isOwnRequest`) as the requests
      // screen, so a reload under the new identity is required here too.
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
      _loadData();
    }
  }

  /// Whether the anonymous roadmap-view policy gates this screen: with config
  /// resolved, anonymous sessions may not load the board at all.
  bool _isAnonymousViewGated({bool listen = true}) {
    final config = CupThreadTheme.configOf(context, listen: listen);
    return config != null &&
        !config.allowAnonymousRoadmap &&
        CupThreadTheme.isAnonymous(context);
  }

  /// Whether the server's `allowedPlatforms` policy gates this screen: with
  /// config resolved, the effective platform is not authorized to run the
  /// SDK at all. Mirrors `FeatureRequestsScreen._isPlatformGated`.
  bool _isPlatformGated({bool listen = true}) {
    return !CupThreadTheme.isPlatformAllowed(context, listen: listen);
  }

  Future<void> _loadData() async {
    // Async completion paths (sheet callbacks) can invoke this after dispose;
    // bail before any context lookups on a defunct element.
    if (!mounted) return;
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.roadmap,
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
        client.fetchColumns(),
        client.fetchFeatureRequests(userToken: userToken, limit: 100),
      ]);

      final cols =
          (results[0] as List<BoardColumn>).where((c) => c.isVisible).toList();
      final page = results[1] as ListFeatureRequestsResult;
      final reqs = page.requests;

      if (mounted && generation == _requestGeneration) {
        setState(() {
          _columns = cols;
          _requests = reqs;
          _total = page.total;
          _rawOffset = page.pageRowCount;
          _nextCursor = page.nextCursor;
          // Reconcile the selection against the fresh column set: a column
          // deleted or hidden server-side between loads must not leave
          // `_selectedColumnId` pointing at a dead id, or the tab bar
          // highlights nothing while the list falls back to the first
          // column's items. Keep the user's selection when the column still
          // exists — that is the common reload case.
          if (_selectedColumnId == null ||
              !cols.any((c) => c.id == _selectedColumnId)) {
            _selectedColumnId = cols.isNotEmpty ? cols[0].id : null;
          }
          _isLoading = false;
          _isLoadingMore = false;
          _loadError = null;
          // A page request started while this refresh was pending captured
          // the same generation; invalidate it so its stale offset cannot
          // append pre-refresh items onto the replaced board.
          _requestGeneration++;
        });
      }
    } catch (e) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);
    final generation = _requestGeneration;
    final sentCursor = _nextCursor;

    setState(() => _isLoadingMore = true);
    try {
      final res = await client.fetchFeatureRequests(
        userToken: userToken,
        limit: 100,
        offset: _rawOffset,
        // When the server mints cursors, follow the keyset page instead of
        // the legacy offset: cursor pages cannot skip or duplicate rows
        // when moderation reorders them between fetches. Sending both
        // parameters would be ambiguous, so the client omits `offset`
        // whenever a cursor is present. Mirrors
        // `FeatureRequestsScreen._loadMore` — both screens consume the
        // same paged endpoint.
        cursor: sentCursor,
      );
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _requests = [..._requests, ...res.requests];
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
    if (!CupThreadTheme.isFeatureEnabled(context, (f) => f.roadmap,
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
        _requests = _requests
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
          _requests = _requests
              .map((i) => i.id == target.id
                  ? i.copyWith(hasVoted: res.voted, voteCount: res.voteCount)
                  : i)
              .toList();
        });
      } else if (mounted) {
        // A reload replaced the board while the vote was in flight. The
        // response's `voted` belongs to the session that cast the vote —
        // applying it would overwrite the reloaded identity's `hasVoted` —
        // but `voteCount` is global, so a stale response still reconciles
        // the count without touching the new session's voted state.
        setState(() {
          _requests = _requests
              .map(
                (i) => i.id == target.id
                    ? i.copyWith(voteCount: res.voteCount)
                    : i,
              )
              .toList();
        });
      }
    } catch (_) {
      // Roll back only while no reload replaced the board; a reloaded board
      // is newer server state than this vote's pre-vote snapshot.
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _requests =
              _requests.map((i) => i.id == target.id ? target : i).toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _votingIds.remove(target.id));
      }
    }
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(
              strings.failedToLoadRequests,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final strings = CupThreadTheme.stringsOf(context);
    final isConfigLoading = CupThreadTheme.isConfigLoading(context);
    final configError = CupThreadTheme.configErrorOf(context);
    final appConfig = CupThreadTheme.configOf(context);
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.roadmap,
    );

    if (isConfigLoading && appConfig == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.roadmap,
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
            widget.title ?? strings.roadmap,
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
            widget.title ?? strings.roadmap,
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
                  strings.roadmapDisabled,
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
            widget.title ?? strings.roadmap,
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
            widget.title ?? strings.roadmap,
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

    final activeColumn = _columns.firstWhere(
      (c) => c.id == _selectedColumnId,
      orElse: () => _columns.isNotEmpty
          ? _columns.first
          : const BoardColumn(
              id: '',
              appId: '',
              name: '',
              slug: '',
              position: 0,
              isVisible: true,
              isSystem: false,
              kind: BoardColumnKind.normal,
              createdAt: '',
              updatedAt: '',
            ),
    );

    final columnItems = _requests.where((r) {
      if (activeColumn.id.isEmpty) return true;
      return r.columnId == activeColumn.id ||
          (r.columnId == null && r.status == activeColumn.slug);
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text(
          widget.title ?? strings.roadmap,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _loadError != null
              ? _buildLoadError(colors, strings)
              : Column(
                  children: [
                    // Column tabs
                    if (_columns.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: colors.card,
                          border:
                              Border(bottom: BorderSide(color: colors.border)),
                        ),
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _columns.length,
                          itemBuilder: (ctx, idx) {
                            final col = _columns[idx];
                            final isSelected = col.id == _selectedColumnId;
                            final count = _requests
                                .where((r) =>
                                    r.columnId == col.id ||
                                    (r.columnId == null &&
                                        r.status == col.slug))
                                .length;

                            return InkWell(
                              onTap: () =>
                                  setState(() => _selectedColumnId = col.id),
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isSelected
                                          ? colors.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '${col.name} ($count)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colors.textPrimary
                                        : colors.textMuted,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Cards list
                    Expanded(
                      child: (columnItems.isEmpty && !_hasMore)
                          ? Center(
                              child: Text(
                                strings.noItemsInColumn,
                                style: TextStyle(color: colors.textMuted),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: colors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount:
                                    columnItems.length + (_hasMore ? 1 : 0),
                                itemBuilder: (ctx, idx) {
                                  if (idx >= columnItems.length) {
                                    return _buildLoadMoreRow(colors, strings);
                                  }
                                  final item = columnItems[idx];
                                  return Card(
                                    color: colors.card,
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side:
                                          BorderSide(color: colors.cardBorder),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () =>
                                          FeatureRequestDetailSheet.show(
                                        context,
                                        item: item,
                                        onVoteChange: (updated) {
                                          if (!mounted) return;
                                          setState(() {
                                            _requests = _requests
                                                .map((i) => i.id == updated.id
                                                    ? updated
                                                    : i)
                                                .toList();
                                          });
                                        },
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item.title,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: colors
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                      if (item.versionLabel !=
                                                          null) ...[
                                                        const SizedBox(
                                                            height: 4),
                                                        BadgeChip(
                                                          label:
                                                              'v${item.versionLabel}',
                                                          isOutline: true,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                VoteButton(
                                                  voteCount: item.voteCount,
                                                  hasVoted: item.hasVoted,
                                                  onPress: () =>
                                                      _handleToggleVote(item),
                                                  disabled: item.isOwnRequest ||
                                                      _votingIds
                                                          .contains(item.id),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.description,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colors.textSecondary,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
