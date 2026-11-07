import 'package:flutter/material.dart';
import '../client/feedback_exception.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import '../utils/formatters.dart';
import 'avatar.dart';

/// Screen presenting a public user/developer profile page.
class UserProfileView extends StatefulWidget {
  final String userId;

  const UserProfileView({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  PublicUserProfileResult? _data;
  bool _isLoading = true;
  Object? _error;

  /// Bumped whenever [UserProfileView.userId] changes or a retry starts, so
  /// a response captured under an earlier id or load can never mutate the
  /// currently displayed user's state.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(UserProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _data = null;
      _isLoading = true;
      _error = null;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final client = CupThreadTheme.clientOf(context);
    final userId = widget.userId;
    final loadGeneration = ++_loadGeneration;
    try {
      final res = await client.fetchUserProfile(userId);
      if (_isCurrentLoad(userId, loadGeneration)) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_isCurrentLoad(userId, loadGeneration)) {
        setState(() {
          // A 404 means the id is unknown or not an app-scoped `u_*` id;
          // fall through to the dedicated "user not found" copy instead of
          // the generic failure message.
          _error = (e is UnexpectedStatusException && e.status == 404) ? null : e;
          _isLoading = false;
        });
      }
    }
  }

  bool _isCurrentLoad(String userId, int loadGeneration) =>
      mounted &&
      widget.userId == userId &&
      loadGeneration == _loadGeneration;

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
          strings.userProfile,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _error != null || _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null) ...[
                          Icon(Icons.cloud_off,
                              size: 36,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          _error != null
                              ? strings.localizedErrorMessage(_error!)
                              : strings.userNotFound,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                        // Retry only makes sense for a transient failure; an
                        // unknown-id 404 renders static "user not found" copy.
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _loadProfile();
                            },
                            child: Text(strings.retry),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Profile Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Avatar(
                              url: _data!.profile.avatarUrl,
                              name: _data!.profile.displayName,
                              size: 64,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _data!.profile.displayName ?? strings.anonymous,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (_data!.profile.bio != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _data!.profile.bio!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Apps
                      if (_data!.publicApps.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${strings.appsSection} (${_data!.publicApps.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._data!.publicApps.map(
                          (app) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (app.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    app.description!,
                                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Comments — the API already gates these on the
                      // user's hideComments privacy setting.
                      if (_data!.recentComments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            strings.recentComments,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._data!.recentComments.map(
                          (c) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.commentOnLabel(c.featureRequestTitle),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '"${c.body}"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatRelativeDate(c.createdAt, strings: strings)} · ${c.appName}',
                                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
