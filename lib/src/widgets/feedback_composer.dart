import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';

/// Form screen for composing and submitting user feedback.
class FeedbackComposer extends StatefulWidget {
  final FeedbackDraft? initialDraft;
  final ValueChanged<FeedbackSubmissionResult>? onSubmitSuccess;

  const FeedbackComposer({
    super.key,
    this.initialDraft,
    this.onSubmitSuccess,
  });

  /// Presents the composer inside a bottom sheet or dialog.
  static Future<FeedbackSubmissionResult?> showModal(
    BuildContext context, {
    FeedbackDraft? initialDraft,
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
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialDraft?.title ?? '');
    _descController = TextEditingController(text: widget.initialDraft?.description ?? '');
    _nameController = TextEditingController(text: widget.initialDraft?.reporterName ?? '');
    _emailController = TextEditingController(text: widget.initialDraft?.reporterEmail ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.length < 3) {
      setState(() => _errorMessage = 'Please provide a title with at least 3 characters.');
      return;
    }
    if (desc.length < 5) {
      setState(() => _errorMessage = 'Please provide details with at least 5 characters.');
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
        attachments: widget.initialDraft?.attachments ?? [],
      );

      final result = await client.submit(draft, userToken: userToken);
      if (mounted) {
        if (widget.onSubmitSuccess != null) {
          widget.onSubmitSuccess!(result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback sent! Thank you.')),
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text(
          'Send Feedback',
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
              'Title *',
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
                hintText: 'Brief summary...',
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
              'Details *',
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
                hintText: 'What happened and what did you expect?',
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
              'Your Name (optional)',
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
                hintText: 'e.g. Alex',
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
              'Email for replies (optional)',
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
                hintText: 'alex@example.com',
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
                  : const Text(
                      'Submit Feedback',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
