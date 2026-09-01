import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import 'badge.dart';
import 'feature_request_detail_sheet.dart';
import 'vote_button.dart';

/// Screen presenting the app's Kanban roadmap board grouped by stage columns.
class RoadmapBoardScreen extends StatefulWidget {
  final String title;

  const RoadmapBoardScreen({
    super.key,
    this.title = 'Roadmap',
  });

  @override
  State<RoadmapBoardScreen> createState() => _RoadmapBoardScreenState();
}

class _RoadmapBoardScreenState extends State<RoadmapBoardScreen> {
  List<BoardColumn> _columns = [];
  List<FeatureRequestItem> _requests = [];
  String? _selectedColumnId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    try {
      final results = await Future.wait([
        client.fetchColumns(),
        client.fetchFeatureRequests(userToken: userToken, limit: 100),
      ]);

      final cols = (results[0] as List<BoardColumn>).where((c) => c.isVisible).toList();
      final reqs = (results[1] as ListFeatureRequestsResult).requests;

      if (mounted) {
        setState(() {
          _columns = cols;
          _requests = reqs;
          if (cols.isNotEmpty && _selectedColumnId == null) {
            _selectedColumnId = cols[0].id;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleToggleVote(FeatureRequestItem target) async {
    if (target.isOwnRequest) return;

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    final nextVoted = !target.hasVoted;
    final nextCount = target.voteCount + (nextVoted ? 1 : -1);

    setState(() {
      _requests = _requests
          .map((i) => i.id == target.id
              ? i.copyWith(hasVoted: nextVoted, voteCount: nextCount < 0 ? 0 : nextCount)
              : i)
          .toList();
    });

    try {
      final res = await client.toggleVote(target.id, userToken: userToken);
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
          _requests = _requests.map((i) => i.id == target.id ? target : i).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);

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
          widget.title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : Column(
              children: [
                // Column tabs
                if (_columns.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      border: Border(bottom: BorderSide(color: colors.border)),
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
                                (r.columnId == null && r.status == col.slug))
                            .length;

                        return InkWell(
                          onTap: () => setState(() => _selectedColumnId = col.id),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? colors.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              '${col.name} ($count)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? colors.textPrimary : colors.textMuted,
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
                            'No items in this milestone.',
                            style: TextStyle(color: colors.textMuted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: colors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: columnItems.length,
                            itemBuilder: (ctx, idx) {
                              final item = columnItems[idx];
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
                                    onVoteChange: (updated) {
                                      setState(() {
                                        _requests = _requests
                                            .map((i) => i.id == updated.id ? updated : i)
                                            .toList();
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.title,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: colors.textPrimary,
                                                    ),
                                                  ),
                                                  if (item.versionLabel != null) ...[
                                                    const SizedBox(height: 4),
                                                    BadgeChip(
                                                      label: 'v${item.versionLabel}',
                                                      isOutline: true,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            VoteButton(
                                              voteCount: item.voteCount,
                                              hasVoted: item.hasVoted,
                                              onPress: () => _handleToggleVote(item),
                                              disabled: item.isOwnRequest,
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
