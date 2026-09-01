import 'package:flutter/material.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = CupThreadTheme.clientOf(context);
    try {
      final res = await client.fetchUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text(
          'User Profile',
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
                  child: Text(
                    _error ?? 'User not found',
                    style: TextStyle(color: colors.textPrimary),
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
                              _data!.profile.displayName ?? 'Anonymous Developer',
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
                      if (_data!.apps.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Apps (${_data!.apps.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._data!.apps.map(
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

                      // Comments
                      if (!_data!.hideComments && _data!.recentComments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Recent Comments',
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
                                  'on ${c.featureRequestTitle}',
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
                                  '${formatRelativeDate(c.createdAt)} · ${c.appName}',
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
