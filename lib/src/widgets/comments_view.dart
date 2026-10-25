import 'package:flutter/material.dart';
import '../client/feedback_exception.dart';
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
  int? _totalComments;
  bool _isLoading = true;
  bool _isPosting = false;
  FeatureRequestComment? _replyingTo;

  /// Page cap for loading the thread, mirroring the client-side walk guard.
  static const int _maxCommentPages = 100;

  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final client = CupThreadTheme.clientOf(context);
    try {
      // Walk the paginated comments endpoint so long threads load completely,
      // capturing the server-reported thread total for the header count. The
      // cursor guard mirrors [FeedbackClient.fetchComments]: a null, unchanged,
      // or revisited cursor can never advance, so stop instead of looping.
      final all = <FeatureRequestComment>[];
      final seenCursors = <String>{};
      String? cursor;
      var hasMore = true;
      int? total;
      for (var page = 0; hasMore && page < _maxCommentPages; page++) {
        final result =
            await client.fetchCommentsPage(widget.featureRequestId, cursor: cursor);
        total ??= result.total;
        final next = result.nextCursor;
        final cannotAdvance = result.hasMore &&
            (next == null || next == cursor || seenCursors.contains(next));
        if (!cannotAdvance || cursor == null) {
          all.addAll(result.comments);
        }
        if (next != null) seenCursors.add(next);
        hasMore = result.hasMore;
        cursor = next;
        if (cannotAdvance) break;
      }
      if (mounted) {
        setState(() {
          _comments = all;
          _totalComments = total;
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
      // Author attribution is resolved server-side from the signed-in
      // profile, so the draft carries no client-supplied author fields.
      // A reply target whose id never arrived (e.g. a comment parsed from
      // a legacy flat fixture) must not be sent as `parentId: ''` — the
      // API rejects that with 400 invalid_parent — so it degrades to a
      // top-level comment.
      final target = _replyingTo;
      final canReply = target != null && target.id.trim().isNotEmpty;
      final draft = CommentDraft(
        body: body,
        parentId: canReply ? target.id : null,
        replyToClerkId: canReply ? target.authorClerkId : null,
        replyToAuthorName: canReply ? target.authorName : null,
      );

      final newComment = await client.postComment(
        widget.featureRequestId,
        draft,
        userToken: userToken,
      );

      if (mounted) {
        setState(() {
          _comments.add(newComment);
          if (_totalComments != null) _totalComments = _totalComments! + 1;
          _textController.clear();
          _replyingTo = null;
          _isPosting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        final strings = CupThreadTheme.stringsOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is TurnstileRequiredException
                ? strings.verificationRequired
                : e is AuthenticationRequiredException
                    ? strings.signInRequiredToComment
                    : strings.commentPostFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final strings = CupThreadTheme.stringsOf(context);
    final visibleComments = _comments.where((c) => !c.isHidden).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${strings.comments} (${_totalComments ?? visibleComments.length})',
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
              strings.noCommentsYet,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: colors.textMuted,
                fontSize: 13,
              ),
            ),
          )
        else
          ...visibleComments.map((comment) => _buildCommentItem(comment, colors, strings)),
        const SizedBox(height: 12),
        // The public API accepts comment writes from a Clerk end-user session
        // only; the SDK's anonymous X-User-Token identity is always rejected
        // with 401, so an anonymous session gets a sign-in notice instead of
        // a compose box that can never succeed.
        if (CupThreadTheme.isAnonymous(context))
          _buildSignInNotice(colors, strings)
        else
          _buildComposeBox(colors, strings),
      ],
    );
  }

  Widget _buildCommentItem(
      FeatureRequestComment comment, CupThreadColors colors, CupThreadStrings strings) {
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
                comment.authorName ?? strings.anonymous,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatRelativeDate(comment.createdAt, strings: strings),
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
                strings.replyingToLabel('@${comment.replyToAuthorName}'),
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
          // A comment without a usable id cannot be referenced by a reply,
          // so it renders without the reply affordance rather than
          // inviting a reply the API would reject.
          if (comment.id.trim().isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _replyingTo = comment),
              child: Text(
                strings.reply,
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

  Widget _buildSignInNotice(CupThreadColors colors, CupThreadStrings strings) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.signInRequiredToComment,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeBox(CupThreadColors colors, CupThreadStrings strings) {
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
                      strings.replyingToLabel(_replyingTo!.authorName ?? strings.anonymous),
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: Text(
                      strings.cancel,
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
            controller: _textController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: strings.writeAComment,
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
                  : Text(strings.send, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
