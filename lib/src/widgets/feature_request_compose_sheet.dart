import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';

/// Form bottom sheet for composing and submitting a new feature request proposal.
class FeatureRequestComposeSheet extends StatefulWidget {
  final ValueChanged<FeatureRequestSubmissionResult>? onSubmitSuccess;

  const FeatureRequestComposeSheet({
    super.key,
    this.onSubmitSuccess,
  });

  /// Presents the feature request compose sheet inside a modal bottom sheet.
  static Future<FeatureRequestSubmissionResult?> show(
    BuildContext context, {
    ValueChanged<FeatureRequestSubmissionResult>? onSubmitSuccess,
  }) {
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.featureRequests,
    );
    if (!isEnabled) return Future.value(null);

    final client = CupThreadTheme.clientOf(context);
    final token = CupThreadTheme.userTokenOf(context);
    final config = CupThreadTheme.configOf(context, listen: false);
    final failClosed = CupThreadTheme.failClosedOf(context);

    return showModalBottomSheet<FeatureRequestSubmissionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CupThreadTheme(
        client: client,
        userToken: token,
        config: config,
        failClosed: failClosed,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetCtx, scrollController) => Container(
            decoration: BoxDecoration(
              color: CupThreadTheme.of(sheetCtx).background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: FeatureRequestComposeSheet(
              onSubmitSuccess: (res) {
                if (onSubmitSuccess != null) {
                  onSubmitSuccess(res);
                }
                Navigator.of(sheetCtx).maybePop(res);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<FeatureRequestComposeSheet> createState() => _FeatureRequestComposeSheetState();
}

class _FeatureRequestComposeSheetState extends State<FeatureRequestComposeSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _nameController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final strings = CupThreadTheme.stringsOf(context);
    if (!CupThreadTheme.isFeatureEnabled(context, (f) => f.featureRequests, listen: false)) {
      setState(() => _errorMessage = strings.featureRequestsDisabled);
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final name = _nameController.text.trim();

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
      final draft = FeatureRequestDraft(
        title: title,
        description: desc,
        requesterName: name.isNotEmpty ? name : null,
      );

      final result = await client.submitFeatureRequest(draft, userToken: userToken);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (widget.onSubmitSuccess != null) {
          widget.onSubmitSuccess!(result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.featureRequestSubmitted)),
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
    final isConfigLoading = CupThreadTheme.isConfigLoading(context);
    final configError = CupThreadTheme.configErrorOf(context);
    final appConfig = CupThreadTheme.configOf(context);
    final isEnabled = CupThreadTheme.isFeatureEnabled(
      context,
      (f) => f.featureRequests,
    );

    if (isConfigLoading && appConfig == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            strings.newFeatureRequest,
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
            strings.newFeatureRequest,
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
            strings.newFeatureRequest,
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 48, color: colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  strings.featureRequestsDisabled,
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text(
          strings.newFeatureRequest,
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
                hintText: strings.titleHint,
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
                hintText: strings.detailsHint,
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
                      strings.submitRequest,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
