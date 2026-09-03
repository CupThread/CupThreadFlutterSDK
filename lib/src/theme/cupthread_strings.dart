import 'package:flutter/material.dart';

/// Localized strings configuration for CupThread SDK widgets.
class CupThreadStrings {
  // Common
  final String retry;
  final String cancel;
  final String close;
  final String anonymous;
  final String justNow;
  final String minutesAgoSuffix;
  final String hoursAgoSuffix;
  final String daysAgoSuffix;

  // Feature Requests & Board
  final String featureRequests;
  final String proposeFeature;
  final String proposeAnIdea;
  final String searchFeatureRequests;
  final String all;
  final String underReview;
  final String planned;
  final String inProgress;
  final String completed;
  final String noFeatureRequestsFound;
  final String beTheFirstToSuggest;
  final String failedToLoadRequests;
  final String roadmap;
  final String noItemsInColumn;

  // Feature Request Compose Sheet
  final String newFeatureRequest;
  final String titleLabel;
  final String titleHint;
  final String detailsLabel;
  final String detailsHint;
  final String yourNameOptional;
  final String yourNameHint;
  final String submitRequest;
  final String submitting;
  final String featureRequestSubmitted;
  final String titleValidationMin3;
  final String detailsValidationMin5;

  // Feature Request Detail
  final String comments;
  final String writeAComment;
  final String send;
  final String posting;
  final String noCommentsYet;
  final String vote;
  final String voted;

  // Feedback Composer
  final String sendFeedback;
  final String submitFeedback;
  final String feedbackSummaryHint;
  final String feedbackDetailsHint;
  final String emailForRepliesOptional;
  final String emailHint;
  final String feedbackSent;
  final String attachments;
  final String addAttachment;
  final String remove;
  final String attachmentDefaultName;

  // Changelog & What's New
  final String whatsNew;
  final String subscribeToUpdates;
  final String enterYourEmail;
  final String subscribe;
  final String subscribed;
  final String gotIt;
  final String version;

  // User Profile
  final String userProfile;
  final String payingCustomer;
  final String freeTier;

  const CupThreadStrings({
    this.retry = 'Retry',
    this.cancel = 'Cancel',
    this.close = 'Close',
    this.anonymous = 'Anonymous',
    this.justNow = 'Just now',
    this.minutesAgoSuffix = 'm ago',
    this.hoursAgoSuffix = 'h ago',
    this.daysAgoSuffix = 'd ago',

    this.featureRequests = 'Feature Requests',
    this.proposeFeature = 'Propose Feature',
    this.proposeAnIdea = 'Propose an idea',
    this.searchFeatureRequests = 'Search feature requests...',
    this.all = 'All',
    this.underReview = 'Under Review',
    this.planned = 'Planned',
    this.inProgress = 'In Progress',
    this.completed = 'Completed',
    this.noFeatureRequestsFound = 'No feature requests found',
    this.beTheFirstToSuggest = 'Be the first to suggest an idea!',
    this.failedToLoadRequests = 'Failed to load requests',
    this.roadmap = 'Roadmap',
    this.noItemsInColumn = 'No items in this column',

    this.newFeatureRequest = 'Propose a Feature',
    this.titleLabel = 'Title *',
    this.titleHint = 'What should we add or improve?',
    this.detailsLabel = 'Details *',
    this.detailsHint = 'Explain your idea and why it would be helpful...',
    this.yourNameOptional = 'Your Name (optional)',
    this.yourNameHint = 'e.g. Alex',
    this.submitRequest = 'Submit Request',
    this.submitting = 'Submitting...',
    this.featureRequestSubmitted = 'Feature request submitted!',
    this.titleValidationMin3 = 'Please provide a title with at least 3 characters.',
    this.detailsValidationMin5 = 'Please provide details with at least 5 characters.',

    this.comments = 'Comments',
    this.writeAComment = 'Write a comment...',
    this.send = 'Send',
    this.posting = 'Posting...',
    this.noCommentsYet = 'No comments yet. Start the conversation!',
    this.vote = 'Vote',
    this.voted = 'Voted',

    this.sendFeedback = 'Send Feedback',
    this.submitFeedback = 'Submit Feedback',
    this.feedbackSummaryHint = 'Brief summary...',
    this.feedbackDetailsHint = 'What happened and what did you expect?',
    this.emailForRepliesOptional = 'Email for replies (optional)',
    this.emailHint = 'alex@example.com',
    this.feedbackSent = 'Feedback sent! Thank you.',
    this.attachments = 'Attachments',
    this.addAttachment = 'Add Attachment',
    this.remove = 'Remove',
    this.attachmentDefaultName = 'Attachment',

    this.whatsNew = "What's New",
    this.subscribeToUpdates = 'Stay updated on new releases',
    this.enterYourEmail = 'Enter your email',
    this.subscribe = 'Subscribe',
    this.subscribed = 'Subscribed!',
    this.gotIt = 'Got it',
    this.version = 'Version',

    this.userProfile = 'User Profile',
    this.payingCustomer = 'Paying Customer',
    this.freeTier = 'Free Tier',
  });

  /// Built-in English strings.
  static const en = CupThreadStrings();

  /// Built-in Simplified Chinese strings.
  static const zhHans = CupThreadStrings(
    retry: '重试',
    cancel: '取消',
    close: '关闭',
    anonymous: '匿名用户',
    justNow: '刚刚',
    minutesAgoSuffix: '分钟前',
    hoursAgoSuffix: '小时前',
    daysAgoSuffix: '天前',

    featureRequests: '功能建议',
    proposeFeature: '提交建议',
    proposeAnIdea: '提出新想法',
    searchFeatureRequests: '搜索功能建议...',
    all: '全部',
    underReview: '评审中',
    planned: '已排期',
    inProgress: '开发中',
    completed: '已完成',
    noFeatureRequestsFound: '暂无相关功能建议',
    beTheFirstToSuggest: '成为第一个提出建议的人吧！',
    failedToLoadRequests: '加载功能建议失败',
    roadmap: '产品路线图',
    noItemsInColumn: '该阶段暂无内容',

    newFeatureRequest: '新建功能建议',
    titleLabel: '标题 *',
    titleHint: '希望增加或改进什么？',
    detailsLabel: '详情 *',
    detailsHint: '详细描述您的想法及应用场景...',
    yourNameOptional: '您的称呼（选填）',
    yourNameHint: '例如：张三',
    submitRequest: '提交建议',
    submitting: '提交中...',
    featureRequestSubmitted: '建议提交成功！',
    titleValidationMin3: '标题至少需要 3 个字符。',
    detailsValidationMin5: '详情至少需要 5 个字符。',

    comments: '讨论',
    writeAComment: '写下您的看法...',
    send: '发送',
    posting: '发送中...',
    noCommentsYet: '暂无讨论，快来发表第一条观点吧！',
    vote: '投票',
    voted: '已投票',

    sendFeedback: '问题与反馈',
    submitFeedback: '提交反馈',
    feedbackSummaryHint: '简要概述...',
    feedbackDetailsHint: '发生了什么？您期望的结果是？',
    emailForRepliesOptional: '联系邮箱（选填，用于回复）',
    emailHint: 'yourname@example.com',
    feedbackSent: '感谢您的反馈！',
    attachments: '附件',
    addAttachment: '添加附件',
    remove: '删除',
    attachmentDefaultName: '附件',

    whatsNew: '新版特性',
    subscribeToUpdates: '订阅最新版本动态',
    enterYourEmail: '输入您的邮箱',
    subscribe: '订阅',
    subscribed: '已订阅！',
    gotIt: '我知道了',
    version: '版本',

    userProfile: '用户资料',
    payingCustomer: '付费用户',
    freeTier: '免费版',
  );

  /// Resolves the appropriate strings based on the given locale.
  static CupThreadStrings fromLocale(Locale? locale) {
    if (locale == null) return en;
    final code = locale.languageCode.toLowerCase();
    if (code == 'zh') {
      return zhHans;
    }
    return en;
  }

  /// Copies existing strings while overriding specified values.
  CupThreadStrings copyWith({
    String? retry,
    String? cancel,
    String? close,
    String? anonymous,
    String? justNow,
    String? minutesAgoSuffix,
    String? hoursAgoSuffix,
    String? daysAgoSuffix,
    String? featureRequests,
    String? proposeFeature,
    String? proposeAnIdea,
    String? searchFeatureRequests,
    String? all,
    String? underReview,
    String? planned,
    String? inProgress,
    String? completed,
    String? noFeatureRequestsFound,
    String? beTheFirstToSuggest,
    String? failedToLoadRequests,
    String? roadmap,
    String? noItemsInColumn,
    String? newFeatureRequest,
    String? titleLabel,
    String? titleHint,
    String? detailsLabel,
    String? detailsHint,
    String? yourNameOptional,
    String? yourNameHint,
    String? submitRequest,
    String? submitting,
    String? featureRequestSubmitted,
    String? titleValidationMin3,
    String? detailsValidationMin5,
    String? comments,
    String? writeAComment,
    String? send,
    String? posting,
    String? noCommentsYet,
    String? vote,
    String? voted,
    String? sendFeedback,
    String? submitFeedback,
    String? feedbackSummaryHint,
    String? feedbackDetailsHint,
    String? emailForRepliesOptional,
    String? emailHint,
    String? feedbackSent,
    String? attachments,
    String? addAttachment,
    String? remove,
    String? attachmentDefaultName,
    String? whatsNew,
    String? subscribeToUpdates,
    String? enterYourEmail,
    String? subscribe,
    String? subscribed,
    String? gotIt,
    String? version,
    String? userProfile,
    String? payingCustomer,
    String? freeTier,
  }) {
    return CupThreadStrings(
      retry: retry ?? this.retry,
      cancel: cancel ?? this.cancel,
      close: close ?? this.close,
      anonymous: anonymous ?? this.anonymous,
      justNow: justNow ?? this.justNow,
      minutesAgoSuffix: minutesAgoSuffix ?? this.minutesAgoSuffix,
      hoursAgoSuffix: hoursAgoSuffix ?? this.hoursAgoSuffix,
      daysAgoSuffix: daysAgoSuffix ?? this.daysAgoSuffix,
      featureRequests: featureRequests ?? this.featureRequests,
      proposeFeature: proposeFeature ?? this.proposeFeature,
      proposeAnIdea: proposeAnIdea ?? this.proposeAnIdea,
      searchFeatureRequests: searchFeatureRequests ?? this.searchFeatureRequests,
      all: all ?? this.all,
      underReview: underReview ?? this.underReview,
      planned: planned ?? this.planned,
      inProgress: inProgress ?? this.inProgress,
      completed: completed ?? this.completed,
      noFeatureRequestsFound: noFeatureRequestsFound ?? this.noFeatureRequestsFound,
      beTheFirstToSuggest: beTheFirstToSuggest ?? this.beTheFirstToSuggest,
      failedToLoadRequests: failedToLoadRequests ?? this.failedToLoadRequests,
      roadmap: roadmap ?? this.roadmap,
      noItemsInColumn: noItemsInColumn ?? this.noItemsInColumn,
      newFeatureRequest: newFeatureRequest ?? this.newFeatureRequest,
      titleLabel: titleLabel ?? this.titleLabel,
      titleHint: titleHint ?? this.titleHint,
      detailsLabel: detailsLabel ?? this.detailsLabel,
      detailsHint: detailsHint ?? this.detailsHint,
      yourNameOptional: yourNameOptional ?? this.yourNameOptional,
      yourNameHint: yourNameHint ?? this.yourNameHint,
      submitRequest: submitRequest ?? this.submitRequest,
      submitting: submitting ?? this.submitting,
      featureRequestSubmitted: featureRequestSubmitted ?? this.featureRequestSubmitted,
      titleValidationMin3: titleValidationMin3 ?? this.titleValidationMin3,
      detailsValidationMin5: detailsValidationMin5 ?? this.detailsValidationMin5,
      comments: comments ?? this.comments,
      writeAComment: writeAComment ?? this.writeAComment,
      send: send ?? this.send,
      posting: posting ?? this.posting,
      noCommentsYet: noCommentsYet ?? this.noCommentsYet,
      vote: vote ?? this.vote,
      voted: voted ?? this.voted,
      sendFeedback: sendFeedback ?? this.sendFeedback,
      submitFeedback: submitFeedback ?? this.submitFeedback,
      feedbackSummaryHint: feedbackSummaryHint ?? this.feedbackSummaryHint,
      feedbackDetailsHint: feedbackDetailsHint ?? this.feedbackDetailsHint,
      emailForRepliesOptional: emailForRepliesOptional ?? this.emailForRepliesOptional,
      emailHint: emailHint ?? this.emailHint,
      feedbackSent: feedbackSent ?? this.feedbackSent,
      attachments: attachments ?? this.attachments,
      addAttachment: addAttachment ?? this.addAttachment,
      remove: remove ?? this.remove,
      attachmentDefaultName: attachmentDefaultName ?? this.attachmentDefaultName,
      whatsNew: whatsNew ?? this.whatsNew,
      subscribeToUpdates: subscribeToUpdates ?? this.subscribeToUpdates,
      enterYourEmail: enterYourEmail ?? this.enterYourEmail,
      subscribe: subscribe ?? this.subscribe,
      subscribed: subscribed ?? this.subscribed,
      gotIt: gotIt ?? this.gotIt,
      version: version ?? this.version,
      userProfile: userProfile ?? this.userProfile,
      payingCustomer: payingCustomer ?? this.payingCustomer,
      freeTier: freeTier ?? this.freeTier,
    );
  }
}
