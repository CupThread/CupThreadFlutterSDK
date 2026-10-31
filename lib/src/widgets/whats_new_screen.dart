import 'package:flutter/material.dart';
import '../client/feedback_exception.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import '../utils/formatters.dart';
import 'badge.dart';
import 'markdown_text.dart';

/// Screen presenting changelog release notes with email subscription.
class WhatsNewScreen extends StatefulWidget {
  final String? title;

  const WhatsNewScreen({
    super.key,
    this.title,
  });

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  List<ChangelogEntry> _entries = [];
  bool _isLoading = true;
  Object? _loadError;
  bool _isSubscribed = false;
  bool _isSubscribing = false;

  final TextEditingController _emailController = TextEditingController();
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
      (f) => f.changelog,
    );

    if (configError != null && appConfig == null && !isEnabled) return;
    if (!isEnabled) return;
    if (_isAnonymousViewGated()) return;

    if (!_hasAttemptedLoad || _lastConfig != appConfig) {
      _lastConfig = appConfig;
      _hasAttemptedLoad = true;
      _loadError = null;
      _loadData();
    }
  }

  /// Whether the anonymous changelog-view policy gates this screen: with
  /// config resolved, anonymous sessions may not browse the changelog.
  bool _isAnonymousViewGated({bool listen = true}) {
    final config = CupThreadTheme.configOf(context, listen: listen);
    return config != null &&
        !config.allowAnonymousChangelog &&
        CupThreadTheme.isAnonymous(context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.changelog,
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

    final client = CupThreadTheme.clientOf(context);
    try {
      final list = await client.fetchChangelog();
      if (mounted) {
        setState(() {
          _entries = list;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSubscribe() async {
    if (!CupThreadTheme.isFeatureEnabled(context, (f) => f.changelog, listen: false)) {
      return;
    }

    final strings = CupThreadTheme.stringsOf(context);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.emailInvalid)),
      );
      return;
    }

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    setState(() => _isSubscribing = true);

    try {
      await client.subscribeToChangelog(email, userToken: userToken);
      if (mounted) {
        setState(() {
          _isSubscribed = true;
          _isSubscribing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.subscribedToUpdates)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is TurnstileRequiredException
                ? strings.verificationRequired
                : strings.subscriptionFailed),
          ),
        );
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
      (f) => f.changelog,
    );

    if (isConfigLoading && appConfig == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.whatsNew,
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
            widget.title ?? strings.whatsNew,
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
                Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
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
            widget.title ?? strings.whatsNew,
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
                  strings.changelogDisabled,
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
            widget.title ?? strings.whatsNew,
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            widget.title ?? strings.whatsNew,
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

    if (_loadError != null && _entries.isEmpty) {
      return _buildLoadError(colors, strings);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text(
          widget.title ?? strings.whatsNew,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
              onRefresh: _loadData,
              color: colors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Subscribe card
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.subscribeToUpdates,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isSubscribed)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.chipBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '✓ ${strings.subscribed} (${_emailController.text})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: strings.enterYourEmail,
                                    hintStyle:
                                        TextStyle(color: colors.textMuted, fontSize: 13),
                                    isDense: true,
                                    filled: true,
                                    fillColor: colors.inputBg,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
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
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isSubscribing ? null : _handleSubscribe,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.primaryText,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _isSubscribing
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.primaryText,
                                        ),
                                      )
                                    : Text(strings.subscribe, style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Entries
                  ..._entries.map((entry) => _buildEntryCard(entry, colors, strings)),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryCard(
      ChangelogEntry entry, CupThreadColors colors, CupThreadStrings strings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (entry.versionLabel != null)
                BadgeChip(
                  label: 'v${entry.versionLabel}',
                  isOutline: true,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatRelativeDate(entry.publishedAt, strings: strings),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          if (entry.linkedRequests.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              children: entry.linkedRequests
                  .map((r) => BadgeChip(label: '★ ${r.title}'))
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          MarkdownText(content: entry.body),
        ],
      ),
    );
  }

  Widget _buildLoadError(CupThreadColors colors, CupThreadStrings strings) {
    final isAuthError = _loadError is AuthenticationRequiredException;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text(
          widget.title ?? strings.whatsNew,
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
              Icon(
                isAuthError ? Icons.lock_outline : Icons.cloud_off,
                size: 48,
                color: isAuthError
                    ? colors.textMuted
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                isAuthError
                    ? strings.signInRequired
                    : strings.failedToLoadRequests,
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
      ),
    );
  }
}
