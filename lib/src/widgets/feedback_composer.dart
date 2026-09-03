import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import '../utils/formatters.dart';

/// Form screen for composing and submitting user feedback with optional attachments.
class FeedbackComposer extends StatefulWidget {
  final FeedbackDraft? initialDraft;
  final ValueChanged<FeedbackSubmissionResult>? onSubmitSuccess;
  final Future<FeedbackAttachment?> Function()? onPickAttachment;

  const FeedbackComposer({
    super.key,
    this.initialDraft,
    this.onSubmitSuccess,
    this.onPickAttachment,
  });

  /// Presents the composer inside a bottom sheet or dialog.
  static Future<FeedbackSubmissionResult?> showModal(
    BuildContext context, {
    FeedbackDraft? initialDraft,
    Future<FeedbackAttachment?> Function()? onPickAttachment,
  }) {
    final client = CupThreadTheme.clientOf(context);
    final token = CupThreadTheme.userTokenOf(context);

    return showModalBottomSheet<FeedbackSubmissionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CupThreadTheme(
        client: client,
        userToken: token,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetCtx, scrollController) => Container(
            decoration: BoxDecoration(
              color: CupThreadTheme.of(sheetCtx).background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: FeedbackComposer(
              initialDraft: initialDraft,
              onPickAttachment: onPickAttachment,
              onSubmitSuccess: (res) => Navigator.of(sheetCtx).pop(res),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<FeedbackComposer> createState() => _FeedbackComposerState();
}

class _FeedbackComposerState extends State<FeedbackComposer> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final List<FeedbackAttachment> _attachments;

  bool _isSubmitting = false;
  bool _isPickingAttachment = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialDraft?.title ?? '');
    _descController = TextEditingController(text: widget.initialDraft?.description ?? '');
    _nameController = TextEditingController(text: widget.initialDraft?.reporterName ?? '');
    _emailController = TextEditingController(text: widget.initialDraft?.reporterEmail ?? '');
    _attachments = widget.initialDraft?.attachments.toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handlePickAttachment() async {
    if (widget.onPickAttachment == null) return;
    setState(() => _isPickingAttachment = true);
    try {
      final attachment = await widget.onPickAttachment!();
      if (attachment != null && mounted) {
        setState(() => _attachments.add(attachment));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingAttachment = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    final strings = CupThreadTheme.stringsOf(context);
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.length < 3) {
      setState(() => _errorMessage = strings.titleValidationMin3);
      return;
    }
    if (desc.length < 5) {
      setState(() => _errorMessage = strings.detailsValidationMin5);
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    try {
      final draft = FeedbackDraft(
        title: title,
        description: desc,
        reporterName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        reporterEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        platform: widget.initialDraft?.platform ?? FeedbackPlatform.current,
        appVersion: widget.initialDraft?.appVersion,
        buildNumber: widget.initialDraft?.buildNumber,
        metadata: widget.initialDraft?.metadata ?? {},
        attachments: _attachments,
      );

      final result = await client.submit(draft, userToken: userToken);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (widget.onSubmitSuccess != null) {
          widget.onSubmitSuccess!(result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.feedbackSent)),
          );
          Navigator.of(context).maybePop(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
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
          strings.sendFeedback,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: colors.textSecondary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                ),
              ),
            Text(
              strings.titleLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: strings.feedbackSummaryHint,
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: colors.inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            const SizedBox(height: 14),
            Text(
              strings.detailsLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: strings.feedbackDetailsHint,
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: colors.inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            const SizedBox(height: 14),
            Text(
              strings.yourNameOptional,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: strings.yourNameHint,
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: colors.inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            const SizedBox(height: 14),
            Text(
              strings.emailForRepliesOptional,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: strings.emailHint,
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: colors.inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            if (widget.onPickAttachment != null || _attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.attachments,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  if (widget.onPickAttachment != null)
                    TextButton.icon(
                      onPressed: _isPickingAttachment ? null : _handlePickAttachment,
                      icon: _isPickingAttachment
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Icon(Icons.attach_file, size: 16, color: colors.primary),
                      label: Text(
                        strings.addAttachment,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 6),
                Column(
                  children: _attachments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final att = entry.value;
                    final isImage = att.kind == AttachmentKind.image;
                    final sizeStr = formatFileSize(att.size);
                    final displayName = att.filename ?? att.key;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName.isNotEmpty ? displayName : strings.attachmentDefaultName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (sizeStr.isNotEmpty || att.mimeType != null)
                                  Text(
                                    [
                                      if (sizeStr.isNotEmpty) sizeStr,
                                      if (att.mimeType != null) att.mimeType!,
                                    ].join(' • '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: colors.textMuted),
                            tooltip: strings.remove,
                            onPressed: () => setState(() => _attachments.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primaryText,
                      ),
                    )
                  : Text(
                      strings.submitFeedback,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
