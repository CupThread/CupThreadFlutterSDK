import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import '../utils/formatters.dart';
import 'avatar.dart';
import 'markdown_text.dart';

/// Discussion view displaying comments on a feature request with inline composer.
class CommentsView extends StatefulWidget {
  final String featureRequestId;

  const CommentsView({
    super.key,
    required this.featureRequestId,
  });

  @override
  State<CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends State<CommentsView> {
  List<FeatureRequestComment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  FeatureRequestComment? _replyingTo;

  final _textController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final client = CupThreadTheme.clientOf(context);
    try {
      final list = await client.fetchComments(widget.featureRequestId);
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePost() async {
    final body = _textController.text.trim();
    if (body.isEmpty) return;

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    setState(() => _isPosting = true);

    try {
      final draft = CommentDraft(
        body: body,
        authorName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        parentId: _replyingTo?.id,
        replyToClerkId: _replyingTo?.authorClerkId,
        replyToAuthorName: _replyingTo?.authorName,
      );

      final newComment = await client.postComment(
        widget.featureRequestId,
        draft,
        userToken: userToken,
      );

      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _textController.clear();
          _replyingTo = null;
          _isPosting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final visibleComments = _comments.where((c) => !c.isHidden).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discussion (${visibleComments.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: colors.primary),
            ),
          )
        else if (visibleComments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No comments yet. Start the conversation!',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: colors.textMuted,
                fontSize: 13,
              ),
            ),
          )
        else
          ...visibleComments.map((comment) => _buildCommentItem(comment, colors)),
        const SizedBox(height: 12),
        _buildComposeBox(colors),
      ],
    );
  }

  Widget _buildCommentItem(FeatureRequestComment comment, CupThreadColors colors) {
    final isReply = comment.parentId != null;

    return Container(
      margin: EdgeInsets.only(
        left: isReply ? 20 : 0,
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(
                url: comment.authorAvatarUrl,
                name: comment.authorName,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                comment.authorName ?? 'Anonymous User',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatRelativeDate(comment.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          if (comment.replyToAuthorName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Replying to @${comment.replyToAuthorName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.primary,
                ),
              ),
            ),
          const SizedBox(height: 6),
          MarkdownText(content: comment.body),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _replyingTo = comment),
            child: Text(
              'Reply',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeBox(CupThreadColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: colors.chipBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.authorName ?? "Anonymous"}',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Your name (optional)',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
              isDense: true,
              filled: true,
              fillColor: colors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.inputBorder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
              filled: true,
              fillColor: colors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.inputBorder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isPosting ? null : _handlePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryText,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: _isPosting
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primaryText,
                      ),
                    )
                  : const Text('Send', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
