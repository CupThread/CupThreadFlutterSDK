import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import 'badge.dart';
import 'markdown_text.dart';

/// Modal dialog announcing latest published changelog release notes.
class ChangelogOverlay extends StatelessWidget {
  final List<ChangelogEntry> entries;
  final ChangelogOverlayConfig config;
  final bool autoMarkSeen;

  const ChangelogOverlay({
    super.key,
    required this.entries,
    required this.config,
    this.autoMarkSeen = true,
  });

  /// Presents the overlay if new entries are available.
  ///
  /// If [onlyIfUnseen] is true, suppresses presentation if the latest release has already been seen.
  /// If [autoMarkSeen] is true, automatically records the latest release as seen upon presentation/dismissal.
  static Future<void> show(
    BuildContext context, {
    bool onlyIfUnseen = false,
    bool autoMarkSeen = true,
  }) async {
    final client = CupThreadTheme.clientOf(context);
    final data = await client.prepareChangelogOverlay(onlyIfUnseen: onlyIfUnseen);
    if (data == null || data.entries.isEmpty) return;

    if (!context.mounted) return;

    final token = CupThreadTheme.userTokenOf(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CupThreadTheme(
        client: client,
        userToken: token,
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (sheetCtx, scrollController) => Container(
            decoration: BoxDecoration(
              color: CupThreadTheme.of(sheetCtx).card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ChangelogOverlay(
              entries: data.entries,
              config: data.appearance.changelogOverlay,
              autoMarkSeen: autoMarkSeen,
            ),
          ),
        ),
      ),
    );

    if (autoMarkSeen && data.entries.isNotEmpty) {
      final latest = data.entries.first;
      final key = latest.versionLabel ?? latest.id;
      if (key.isNotEmpty) {
        await client.markChangelogSeen(key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final strings = CupThreadTheme.stringsOf(context);
    final titleText = config.title.isNotEmpty ? config.title : strings.whatsNew;
    final buttonText = config.primaryButton.isNotEmpty ? config.primaryButton : strings.gotIt;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            children: [
              Text(
                titleText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              if (config.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  config.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, __) => Divider(color: colors.border),
            itemBuilder: (ctx, idx) {
              final item = entries[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (item.versionLabel != null)
                          BadgeChip(
                            label: 'v${item.versionLabel}',
                            isOutline: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MarkdownText(content: item.body),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (autoMarkSeen && entries.isNotEmpty) {
                  final latest = entries.first;
                  final key = latest.versionLabel ?? latest.id;
                  if (key.isNotEmpty) {
                    try {
                      await CupThreadTheme.clientOf(context).markChangelogSeen(key);
                    } catch (_) {}
                  }
                }
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
