import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import 'badge.dart';
import 'feature_request_detail_sheet.dart';
import 'vote_button.dart';

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
  final Set<String> _votingIds = {};

  PublicAppConfig? _lastConfig;
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

    if (!_hasAttemptedLoad || _lastConfig != appConfig) {
      _lastConfig = appConfig;
      _hasAttemptedLoad = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.roadmap,
      listen: false,
    );
    if (!isEnabled) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    try {
      final results = await Future.wait([
        client.fetchColumns(),
        client.fetchFeatureRequests(userToken: userToken, limit: 100),
      ]);

      final cols =
          (results[0] as List<BoardColumn>).where((c) => c.isVisible).toList();
      final reqs = (results[1] as ListFeatureRequestsResult).requests;

      if (mounted) {
        setState(() {
          _columns = cols;
          _requests = reqs;
          _total = (results[1] as ListFeatureRequestsResult).total;
          if (cols.isNotEmpty && _selectedColumnId == null) {
            _selectedColumnId = cols[0].id;
          }
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _requests.length >= _total) return;
    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    setState(() => _isLoadingMore = true);
    try {
      final res = await client.fetchFeatureRequests(
        userToken: userToken,
        limit: 100,
        offset: _requests.length,
      );
      if (mounted) {
        setState(() {
          _requests = [..._requests, ...res.requests];
          _total = res.total;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      // Keep the current page; the Load more row stays available to retry.
      if (mounted) setState(() => _isLoadingMore = false);
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
        const SnackBar(
            content: Text('Sign-in is required to vote on feature requests.')),
      );
      return;
    }

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    final nextVoted = !target.hasVoted;
    final nextCount = target.voteCount + (nextVoted ? 1 : -1);

    setState(() {
      _votingIds.add(target.id);
      _requests = _requests
          .map((i) => i.id == target.id
              ? i.copyWith(
                  hasVoted: nextVoted, voteCount: nextCount < 0 ? 0 : nextCount)
              : i)
          .toList();
    });

    try {
      final res = target.hasVoted
          ? await client.removeVote(target.id, userToken: userToken)
          : await client.castVote(target.id, userToken: userToken);
      if (mounted) {
        setState(() {
          _requests = _requests
              .map((i) => i.id == target.id
                  ? i.copyWith(hasVoted: res.voted, voteCount: res.voteCount)
                  : i)
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
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

  bool get _hasMore => _requests.length < _total;

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
                      child: columnItems.isEmpty
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
