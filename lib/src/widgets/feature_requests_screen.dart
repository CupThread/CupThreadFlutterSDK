import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import 'avatar.dart';
import 'badge.dart';
import 'feature_request_compose_sheet.dart';
import 'feature_request_detail_sheet.dart';
import 'vote_button.dart';

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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

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

      if (mounted) {
        setState(() {
          _items = requestsRes.requests;
          _versions = versionsRes;
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
      _items = _items
          .map((i) => i.id == target.id
              ? i.copyWith(hasVoted: nextVoted, voteCount: nextCount < 0 ? 0 : nextCount)
              : i)
          .toList();
    });

    try {
      final res = await client.toggleVote(target.id, userToken: userToken);
      if (mounted) {
        setState(() {
          _items = _items
              .map((i) => i.id == target.id
                  ? i.copyWith(hasVoted: res.voted, voteCount: res.voteCount)
                  : i)
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = _items.map((i) => i.id == target.id ? target : i).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final strings = CupThreadTheme.stringsOf(context);

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
            onPressed: () => FeatureRequestComposeSheet.show(context).then((res) {
              if (res != null) _loadData();
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
                setState(() => _query = val.trim());
                _loadData();
              },
              decoration: InputDecoration(
                hintText: strings.searchFeatureRequests,
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: colors.textMuted),
                filled: true,
                fillColor: colors.inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  ..._versions.map((v) => _buildVersionChip(v.id, v.label, colors)),
                ],
              ),
            ),

          // Requests list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
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
                              style: TextStyle(color: colors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  FeatureRequestComposeSheet.show(context).then((res) {
                                if (res != null) _loadData();
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
                          itemCount: _items.length,
                          itemBuilder: (ctx, idx) => _buildRequestCard(_items[idx], colors),
                        ),
                      ),
          ),
        ],
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
              _items = _items.map((i) => i.id == updated.id ? updated : i).toList();
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
                    disabled: item.isOwnRequest,
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
                            child: Avatar(url: c.avatarUrl, name: c.authorName, size: 18),
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
