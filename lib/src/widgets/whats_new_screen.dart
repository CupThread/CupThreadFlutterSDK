import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import '../utils/formatters.dart';
import 'badge.dart';
import 'markdown_text.dart';

/// Screen presenting changelog release notes with email subscription.
class WhatsNewScreen extends StatefulWidget {
  final String title;

  const WhatsNewScreen({
    super.key,
    this.title = "What's New",
  });

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  List<ChangelogEntry> _entries = [];
  bool _isLoading = true;
  bool _isSubscribed = false;
  bool _isSubscribing = false;

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final client = CupThreadTheme.clientOf(context);
    try {
      final list = await client.fetchChangelog();
      if (mounted) {
        setState(() {
          _entries = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubscribe() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
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
          const SnackBar(content: Text("Subscribed! You'll receive email updates.")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription failed: $e')),
        );
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
          : RefreshIndicator(
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
                          'Get notified on new releases',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Subscribe to receive release notes in your inbox.',
                          style: TextStyle(fontSize: 13, color: colors.textSecondary),
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
                              '✓ Subscribed to updates (${_emailController.text})',
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
                                    hintText: 'Enter your email...',
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
                                    : const Text('Subscribe', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Entries
                  ..._entries.map((entry) => _buildEntryCard(entry, colors)),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryCard(ChangelogEntry entry, CupThreadColors colors) {
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
            formatRelativeDate(entry.publishedAt),
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
}
