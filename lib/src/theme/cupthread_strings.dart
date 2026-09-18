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

  // Feature Kill-switches & Remote Config
  final String featureUnavailable;
  final String featureRequestsDisabled;
  final String roadmapDisabled;
  final String feedbackDisabled;
  final String changelogDisabled;
  final String configLoadFailed;
  final String attachmentTooLarge;

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

    this.featureUnavailable = 'This feature is currently unavailable.',
    this.featureRequestsDisabled = 'Feature requests are currently disabled.',
    this.roadmapDisabled = 'Roadmap is currently disabled.',
    this.feedbackDisabled = 'Feedback submission is currently disabled.',
    this.changelogDisabled = 'Changelog is currently disabled.',
    this.configLoadFailed = 'Failed to load configuration.',
    this.attachmentTooLarge = 'Attachment exceeds the maximum allowed size.',
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

  /// Built-in Japanese strings.
  static const ja = CupThreadStrings(
    retry: '再試行',
    cancel: 'キャンセル',
    close: '閉じる',
    anonymous: '匿名',
    justNow: 'たった今',
    minutesAgoSuffix: '分前',
    hoursAgoSuffix: '時間前',
    daysAgoSuffix: '日前',

    featureRequests: '機能リクエスト',
    proposeFeature: '機能を提案',
    proposeAnIdea: 'アイデアを提案する',
    searchFeatureRequests: '機能リクエストを検索...',
    all: 'すべて',
    underReview: '検討中',
    planned: '予定',
    inProgress: '進行中',
    completed: '完了',
    noFeatureRequestsFound: '機能リクエストが見つかりません',
    beTheFirstToSuggest: '最初にアイデアを提案しましょう！',
    failedToLoadRequests: 'リクエストの読み込みに失敗しました',
    roadmap: 'ロードマップ',
    noItemsInColumn: 'このステージにはアイテムがありません',

    newFeatureRequest: '機能を提案する',
    titleLabel: 'タイトル *',
    titleHint: '追加・改善してほしいことは？',
    detailsLabel: '詳細 *',
    detailsHint: 'アイデアと役立つ理由を説明してください...',
    yourNameOptional: 'お名前（任意）',
    yourNameHint: '例：太郎',
    submitRequest: 'リクエストを送信',
    submitting: '送信中...',
    featureRequestSubmitted: '機能リクエストを送信しました！',
    titleValidationMin3: 'タイトルは3文字以上で入力してください。',
    detailsValidationMin5: '詳細は5文字以上で入力してください。',

    comments: 'コメント',
    writeAComment: 'コメントを書く...',
    send: '送信',
    posting: '投稿中...',
    noCommentsYet: 'まだコメントがありません。最初のコメントを投稿しましょう！',
    vote: '投票する',
    voted: '投票済み',

    sendFeedback: 'フィードバックを送る',
    submitFeedback: 'フィードバックを送信',
    feedbackSummaryHint: '概要を簡潔に...',
    feedbackDetailsHint: '何が起こり、どうなることを期待しましたか？',
    emailForRepliesOptional: '返信用メール（任意）',
    emailHint: 'taro@example.com',
    feedbackSent: 'フィードバックを送信しました！ありがとうございます。',
    attachments: '添付ファイル',
    addAttachment: '添付ファイルを追加',
    remove: '削除',
    attachmentDefaultName: '添付ファイル',

    whatsNew: '新機能',
    subscribeToUpdates: '新リリースの最新情報を受け取る',
    enterYourEmail: 'メールアドレスを入力',
    subscribe: '購読する',
    subscribed: '購読しました！',
    gotIt: '了解',
    version: 'バージョン',

    userProfile: 'ユーザープロフィール',
    payingCustomer: '有料ユーザー',
    freeTier: '無料プラン',
  );

  /// Built-in French strings.
  static const fr = CupThreadStrings(
    retry: 'Réessayer',
    cancel: 'Annuler',
    close: 'Fermer',
    anonymous: 'Anonyme',
    justNow: "À l'instant",
    minutesAgoSuffix: ' min',
    hoursAgoSuffix: ' h',
    daysAgoSuffix: ' j',

    featureRequests: 'Demandes de fonctionnalités',
    proposeFeature: 'Proposer une fonctionnalité',
    proposeAnIdea: 'Proposer une idée',
    searchFeatureRequests: 'Rechercher des demandes...',
    all: 'Tout',
    underReview: "En cours d'examen",
    planned: 'Planifié',
    inProgress: 'En cours',
    completed: 'Terminé',
    noFeatureRequestsFound: 'Aucune demande trouvée',
    beTheFirstToSuggest: 'Soyez le premier à proposer une idée !',
    failedToLoadRequests: 'Échec du chargement des demandes',
    roadmap: 'Feuille de route',
    noItemsInColumn: 'Aucun élément dans cette colonne',

    newFeatureRequest: 'Proposer une fonctionnalité',
    titleLabel: 'Titre *',
    titleHint: 'Que devrions-nous ajouter ou améliorer ?',
    detailsLabel: 'Détails *',
    detailsHint: 'Expliquez votre idée et son utilité...',
    yourNameOptional: 'Votre nom (facultatif)',
    yourNameHint: 'ex. Alex',
    submitRequest: 'Envoyer la demande',
    submitting: 'Envoi en cours...',
    featureRequestSubmitted: 'Demande envoyée !',
    titleValidationMin3: "Veuillez saisir un titre d'au moins 3 caractères.",
    detailsValidationMin5: "Veuillez saisir des détails d'au moins 5 caractères.",

    comments: 'Commentaires',
    writeAComment: 'Écrivez un commentaire...',
    send: 'Envoyer',
    posting: 'Publication en cours...',
    noCommentsYet: 'Aucun commentaire. Lancez la discussion !',
    vote: 'Voter',
    voted: 'Voté',

    sendFeedback: 'Envoyer un retour',
    submitFeedback: 'Envoyer le retour',
    feedbackSummaryHint: 'Résumé bref...',
    feedbackDetailsHint: "Que s'est-il passé et à quoi vous attendiez-vous ?",
    emailForRepliesOptional: 'E-mail pour les réponses (facultatif)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Retour envoyé ! Merci.',
    attachments: 'Pièces jointes',
    addAttachment: 'Ajouter une pièce jointe',
    remove: 'Supprimer',
    attachmentDefaultName: 'Pièce jointe',

    whatsNew: 'Nouveautés',
    subscribeToUpdates: 'Restez informé des nouveautés',
    enterYourEmail: 'Saisissez votre e-mail',
    subscribe: "S'abonner",
    subscribed: 'Abonné !',
    gotIt: 'Compris',
    version: 'Version',

    userProfile: 'Profil utilisateur',
    payingCustomer: 'Client payant',
    freeTier: 'Offre gratuite',
  );

  /// Built-in Spanish strings.
  static const es = CupThreadStrings(
    retry: 'Reintentar',
    cancel: 'Cancelar',
    close: 'Cerrar',
    anonymous: 'Anónimo',
    justNow: 'Ahora mismo',
    minutesAgoSuffix: ' min',
    hoursAgoSuffix: ' h',
    daysAgoSuffix: ' d',

    featureRequests: 'Solicitudes de funciones',
    proposeFeature: 'Proponer función',
    proposeAnIdea: 'Proponer una idea',
    searchFeatureRequests: 'Buscar solicitudes...',
    all: 'Todo',
    underReview: 'En revisión',
    planned: 'Planificado',
    inProgress: 'En curso',
    completed: 'Completado',
    noFeatureRequestsFound: 'No se encontraron solicitudes',
    beTheFirstToSuggest: '¡Sé el primero en sugerir una idea!',
    failedToLoadRequests: 'No se pudieron cargar las solicitudes',
    roadmap: 'Hoja de ruta',
    noItemsInColumn: 'No hay elementos en esta columna',

    newFeatureRequest: 'Proponer una función',
    titleLabel: 'Título *',
    titleHint: '¿Qué deberíamos añadir o mejorar?',
    detailsLabel: 'Detalles *',
    detailsHint: 'Explica tu idea y por qué sería útil...',
    yourNameOptional: 'Tu nombre (opcional)',
    yourNameHint: 'p. ej. Alex',
    submitRequest: 'Enviar solicitud',
    submitting: 'Enviando...',
    featureRequestSubmitted: '¡Solicitud enviada!',
    titleValidationMin3: 'El título debe tener al menos 3 caracteres.',
    detailsValidationMin5: 'Los detalles deben tener al menos 5 caracteres.',

    comments: 'Comentarios',
    writeAComment: 'Escribe un comentario...',
    send: 'Enviar',
    posting: 'Publicando...',
    noCommentsYet: 'Aún no hay comentarios. ¡Inicia la conversación!',
    vote: 'Votar',
    voted: 'Votado',

    sendFeedback: 'Enviar comentarios',
    submitFeedback: 'Enviar comentarios',
    feedbackSummaryHint: 'Resumen breve...',
    feedbackDetailsHint: '¿Qué pasó y qué esperabas?',
    emailForRepliesOptional: 'Correo para respuestas (opcional)',
    emailHint: 'alex@example.com',
    feedbackSent: '¡Comentarios enviados! Gracias.',
    attachments: 'Archivos adjuntos',
    addAttachment: 'Añadir adjunto',
    remove: 'Eliminar',
    attachmentDefaultName: 'Adjunto',

    whatsNew: 'Novedades',
    subscribeToUpdates: 'Mantente al día de las novedades',
    enterYourEmail: 'Introduce tu correo',
    subscribe: 'Suscribirse',
    subscribed: '¡Suscrito!',
    gotIt: 'Entendido',
    version: 'Versión',

    userProfile: 'Perfil de usuario',
    payingCustomer: 'Cliente de pago',
    freeTier: 'Plan gratuito',
  );

  /// Built-in German strings.
  static const de = CupThreadStrings(
    retry: 'Wiederholen',
    cancel: 'Abbrechen',
    close: 'Schließen',
    anonymous: 'Anonym',
    justNow: 'Gerade eben',
    minutesAgoSuffix: ' Min.',
    hoursAgoSuffix: ' Std.',
    daysAgoSuffix: ' T.',

    featureRequests: 'Funktionswünsche',
    proposeFeature: 'Funktion vorschlagen',
    proposeAnIdea: 'Idee vorschlagen',
    searchFeatureRequests: 'Funktionswünsche suchen...',
    all: 'Alle',
    underReview: 'In Prüfung',
    planned: 'Geplant',
    inProgress: 'In Umsetzung',
    completed: 'Abgeschlossen',
    noFeatureRequestsFound: 'Keine Funktionswünsche gefunden',
    beTheFirstToSuggest: 'Seien Sie der Erste mit einer Idee!',
    failedToLoadRequests: 'Anfragen konnten nicht geladen werden',
    roadmap: 'Roadmap',
    noItemsInColumn: 'Keine Einträge in dieser Spalte',

    newFeatureRequest: 'Funktion vorschlagen',
    titleLabel: 'Titel *',
    titleHint: 'Was sollen wir hinzufügen oder verbessern?',
    detailsLabel: 'Details *',
    detailsHint: 'Beschreiben Sie Ihre Idee und warum sie hilfreich wäre...',
    yourNameOptional: 'Ihr Name (optional)',
    yourNameHint: 'z. B. Alex',
    submitRequest: 'Anfrage senden',
    submitting: 'Wird gesendet...',
    featureRequestSubmitted: 'Funktionswunsch gesendet!',
    titleValidationMin3: 'Bitte geben Sie einen Titel mit mindestens 3 Zeichen ein.',
    detailsValidationMin5: 'Bitte geben Sie Details mit mindestens 5 Zeichen ein.',

    comments: 'Kommentare',
    writeAComment: 'Kommentar schreiben...',
    send: 'Senden',
    posting: 'Wird gepostet...',
    noCommentsYet: 'Noch keine Kommentare. Starten Sie die Diskussion!',
    vote: 'Abstimmen',
    voted: 'Abgestimmt',

    sendFeedback: 'Feedback geben',
    submitFeedback: 'Feedback senden',
    feedbackSummaryHint: 'Kurze Zusammenfassung...',
    feedbackDetailsHint: 'Was ist passiert und was haben Sie erwartet?',
    emailForRepliesOptional: 'E-Mail für Antworten (optional)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Feedback gesendet! Vielen Dank.',
    attachments: 'Anhänge',
    addAttachment: 'Anhang hinzufügen',
    remove: 'Entfernen',
    attachmentDefaultName: 'Anhang',

    whatsNew: 'Neuigkeiten',
    subscribeToUpdates: 'Bleiben Sie über Neuigkeiten informiert',
    enterYourEmail: 'E-Mail eingeben',
    subscribe: 'Abonnieren',
    subscribed: 'Abonniert!',
    gotIt: 'Verstanden',
    version: 'Version',

    userProfile: 'Benutzerprofil',
    payingCustomer: 'Zahlender Kunde',
    freeTier: 'Gratis-Tarif',
  );

  /// Built-in Italian strings.
  static const it = CupThreadStrings(
    retry: 'Riprova',
    cancel: 'Annulla',
    close: 'Chiudi',
    anonymous: 'Anonimo',
    justNow: 'Proprio ora',
    minutesAgoSuffix: ' min fa',
    hoursAgoSuffix: ' h fa',
    daysAgoSuffix: ' g fa',

    featureRequests: 'Richieste di funzionalità',
    proposeFeature: 'Proponi una funzionalità',
    proposeAnIdea: "Proponi un'idea",
    searchFeatureRequests: 'Cerca richieste...',
    all: 'Tutte',
    underReview: 'In revisione',
    planned: 'Pianificata',
    inProgress: 'In corso',
    completed: 'Completata',
    noFeatureRequestsFound: 'Nessuna richiesta trovata',
    beTheFirstToSuggest: "Sii il primo a proporre un'idea!",
    failedToLoadRequests: 'Impossibile caricare le richieste',
    roadmap: 'Roadmap',
    noItemsInColumn: 'Nessun elemento in questa colonna',

    newFeatureRequest: 'Proponi una funzionalità',
    titleLabel: 'Titolo *',
    titleHint: 'Cosa dovremmo aggiungere o migliorare?',
    detailsLabel: 'Dettagli *',
    detailsHint: 'Spiega la tua idea e perché sarebbe utile...',
    yourNameOptional: 'Il tuo nome (facoltativo)',
    yourNameHint: 'es. Alex',
    submitRequest: 'Invia richiesta',
    submitting: 'Invio in corso...',
    featureRequestSubmitted: 'Richiesta inviata!',
    titleValidationMin3: 'Inserisci un titolo di almeno 3 caratteri.',
    detailsValidationMin5: 'Inserisci dettagli di almeno 5 caratteri.',

    comments: 'Commenti',
    writeAComment: 'Scrivi un commento...',
    send: 'Invia',
    posting: 'Pubblicazione in corso...',
    noCommentsYet: 'Ancora nessun commento. Avvia la conversazione!',
    vote: 'Vota',
    voted: 'Votato',

    sendFeedback: 'Invia un feedback',
    submitFeedback: 'Invia il feedback',
    feedbackSummaryHint: 'Breve riepilogo...',
    feedbackDetailsHint: 'Cosa è successo e cosa ti aspettavi?',
    emailForRepliesOptional: 'E-mail per le risposte (facoltativo)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Feedback inviato! Grazie.',
    attachments: 'Allegati',
    addAttachment: 'Aggiungi allegato',
    remove: 'Rimuovi',
    attachmentDefaultName: 'Allegato',

    whatsNew: 'Novità',
    subscribeToUpdates: 'Resta aggiornato sulle novità',
    enterYourEmail: 'Inserisci la tua e-mail',
    subscribe: 'Iscriviti',
    subscribed: 'Iscritto!',
    gotIt: 'Ho capito',
    version: 'Versione',

    userProfile: 'Profilo utente',
    payingCustomer: 'Cliente pagante',
    freeTier: 'Piano gratuito',
  );

  /// Built-in Portuguese strings.
  static const pt = CupThreadStrings(
    retry: 'Tentar novamente',
    cancel: 'Cancelar',
    close: 'Fechar',
    anonymous: 'Anônimo',
    justNow: 'Agora mesmo',
    minutesAgoSuffix: ' min',
    hoursAgoSuffix: ' h',
    daysAgoSuffix: ' d',

    featureRequests: 'Solicitações de recursos',
    proposeFeature: 'Propor recurso',
    proposeAnIdea: 'Propor uma ideia',
    searchFeatureRequests: 'Pesquisar solicitações...',
    all: 'Todas',
    underReview: 'Em análise',
    planned: 'Planejado',
    inProgress: 'Em andamento',
    completed: 'Concluído',
    noFeatureRequestsFound: 'Nenhuma solicitação encontrada',
    beTheFirstToSuggest: 'Seja o primeiro a sugerir uma ideia!',
    failedToLoadRequests: 'Falha ao carregar solicitações',
    roadmap: 'Roadmap',
    noItemsInColumn: 'Nenhum item nesta coluna',

    newFeatureRequest: 'Propor um recurso',
    titleLabel: 'Título *',
    titleHint: 'O que devemos adicionar ou melhorar?',
    detailsLabel: 'Detalhes *',
    detailsHint: 'Explique sua ideia e por que ela seria útil...',
    yourNameOptional: 'Seu nome (opcional)',
    yourNameHint: 'ex.: Alex',
    submitRequest: 'Enviar solicitação',
    submitting: 'Enviando...',
    featureRequestSubmitted: 'Solicitação enviada!',
    titleValidationMin3: 'Informe um título com pelo menos 3 caracteres.',
    detailsValidationMin5: 'Informe detalhes com pelo menos 5 caracteres.',

    comments: 'Comentários',
    writeAComment: 'Escreva um comentário...',
    send: 'Enviar',
    posting: 'Publicando...',
    noCommentsYet: 'Ainda sem comentários. Inicie a conversa!',
    vote: 'Votar',
    voted: 'Votado',

    sendFeedback: 'Enviar um feedback',
    submitFeedback: 'Enviar o feedback',
    feedbackSummaryHint: 'Resumo breve...',
    feedbackDetailsHint: 'O que aconteceu e o que você esperava?',
    emailForRepliesOptional: 'E-mail para respostas (opcional)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Feedback enviado! Obrigado.',
    attachments: 'Anexos',
    addAttachment: 'Adicionar anexo',
    remove: 'Remover',
    attachmentDefaultName: 'Anexo',

    whatsNew: 'Novidades',
    subscribeToUpdates: 'Fique por dentro das novidades',
    enterYourEmail: 'Digite seu e-mail',
    subscribe: 'Assinar',
    subscribed: 'Inscrito!',
    gotIt: 'Entendi',
    version: 'Versão',

    userProfile: 'Perfil do usuário',
    payingCustomer: 'Cliente pagante',
    freeTier: 'Plano gratuito',
  );

  /// Built-in Traditional Chinese strings.
  static const zhHant = CupThreadStrings(
    retry: '重試',
    cancel: '取消',
    close: '關閉',
    anonymous: '匿名使用者',
    justNow: '剛剛',
    minutesAgoSuffix: '分鐘前',
    hoursAgoSuffix: '小時前',
    daysAgoSuffix: '天前',

    featureRequests: '功能建議',
    proposeFeature: '提交建議',
    proposeAnIdea: '提出新想法',
    searchFeatureRequests: '搜尋功能建議...',
    all: '全部',
    underReview: '審核中',
    planned: '已排期',
    inProgress: '開發中',
    completed: '已完成',
    noFeatureRequestsFound: '暫無相關功能建議',
    beTheFirstToSuggest: '成為第一個提出建議的人吧！',
    failedToLoadRequests: '載入功能建議失敗',
    roadmap: '產品路線圖',
    noItemsInColumn: '該階段暫無內容',

    newFeatureRequest: '新增功能建議',
    titleLabel: '標題 *',
    titleHint: '希望增加或改進什麼？',
    detailsLabel: '詳情 *',
    detailsHint: '詳細描述您的想法及應用場景...',
    yourNameOptional: '您的稱呼（選填）',
    yourNameHint: '例如：張三',
    submitRequest: '提交建議',
    submitting: '提交中...',
    featureRequestSubmitted: '建議提交成功！',
    titleValidationMin3: '標題至少需要 3 個字元。',
    detailsValidationMin5: '詳情至少需要 5 個字元。',

    comments: '討論',
    writeAComment: '寫下您的看法...',
    send: '傳送',
    posting: '傳送中...',
    noCommentsYet: '暫無討論，快來發表第一條觀點吧！',
    vote: '投票',
    voted: '已投票',

    sendFeedback: '問題與回饋',
    submitFeedback: '提交回饋',
    feedbackSummaryHint: '簡要概述...',
    feedbackDetailsHint: '發生了什麼？您期望的結果是？',
    emailForRepliesOptional: '聯絡信箱（選填，用於回覆）',
    emailHint: 'yourname@example.com',
    feedbackSent: '感謝您的回饋！',
    attachments: '附件',
    addAttachment: '新增附件',
    remove: '刪除',
    attachmentDefaultName: '附件',

    whatsNew: '新功能',
    subscribeToUpdates: '訂閱最新版本動態',
    enterYourEmail: '輸入您的信箱',
    subscribe: '訂閱',
    subscribed: '已訂閱！',
    gotIt: '我知道了',
    version: '版本',

    userProfile: '使用者資料',
    payingCustomer: '付費用戶',
    freeTier: '免費版',
  );

  /// Built-in Korean strings.
  static const ko = CupThreadStrings(
    retry: '다시 시도',
    cancel: '취소',
    close: '닫기',
    anonymous: '익명',
    justNow: '방금',
    minutesAgoSuffix: '분 전',
    hoursAgoSuffix: '시간 전',
    daysAgoSuffix: '일 전',

    featureRequests: '기능 요청',
    proposeFeature: '기능 제안하기',
    proposeAnIdea: '아이디어 제안하기',
    searchFeatureRequests: '기능 요청 검색...',
    all: '전체',
    underReview: '검토 중',
    planned: '예정됨',
    inProgress: '진행 중',
    completed: '완료됨',
    noFeatureRequestsFound: '기능 요청을 찾을 수 없습니다',
    beTheFirstToSuggest: '첫 아이디어를 제안해 보세요!',
    failedToLoadRequests: '요청을 불러오지 못했습니다',
    roadmap: '로드맵',
    noItemsInColumn: '이 단계에 항목이 없습니다',

    newFeatureRequest: '기능 제안하기',
    titleLabel: '제목 *',
    titleHint: '추가하거나 개선했으면 하는 점은 무엇인가요?',
    detailsLabel: '세부 내용 *',
    detailsHint: '아이디어와 유용한 이유를 설명해 주세요...',
    yourNameOptional: '이름 (선택 사항)',
    yourNameHint: '예: 민준',
    submitRequest: '요청 제출',
    submitting: '제출 중...',
    featureRequestSubmitted: '기능 요청이 제출되었습니다!',
    titleValidationMin3: '제목은 3자 이상 입력해 주세요.',
    detailsValidationMin5: '세부 내용은 5자 이상 입력해 주세요.',

    comments: '댓글',
    writeAComment: '댓글 작성...',
    send: '보내기',
    posting: '게시 중...',
    noCommentsYet: '아직 댓글이 없습니다. 첫 댓글을 남겨 보세요!',
    vote: '투표하기',
    voted: '투표함',

    sendFeedback: '피드백 보내기',
    submitFeedback: '피드백 제출',
    feedbackSummaryHint: '간단한 요약...',
    feedbackDetailsHint: '어떤 일이 있었고 무엇을 기대하셨나요?',
    emailForRepliesOptional: '답장 받을 이메일 (선택 사항)',
    emailHint: 'minjun@example.com',
    feedbackSent: '피드백을 보내주셔서 감사합니다!',
    attachments: '첨부파일',
    addAttachment: '첨부파일 추가',
    remove: '삭제',
    attachmentDefaultName: '첨부파일',

    whatsNew: '새로운 기능',
    subscribeToUpdates: '새 릴리스 소식을 받아보세요',
    enterYourEmail: '이메일 입력',
    subscribe: '구독하기',
    subscribed: '구독됨!',
    gotIt: '알겠습니다',
    version: '버전',

    userProfile: '사용자 프로필',
    payingCustomer: '유료 사용자',
    freeTier: '무료 플랜',
  );

  /// Built-in Polish strings.
  static const pl = CupThreadStrings(
    retry: 'Spróbuj ponownie',
    cancel: 'Anuluj',
    close: 'Zamknij',
    anonymous: 'Anonim',
    justNow: 'Przed chwilą',
    minutesAgoSuffix: ' min temu',
    hoursAgoSuffix: ' godz. temu',
    daysAgoSuffix: ' dni temu',

    featureRequests: 'Propozycje funkcji',
    proposeFeature: 'Zaproponuj funkcję',
    proposeAnIdea: 'Zaproponuj pomysł',
    searchFeatureRequests: 'Szukaj propozycji...',
    all: 'Wszystkie',
    underReview: 'W trakcie przeglądu',
    planned: 'Zaplanowane',
    inProgress: 'W realizacji',
    completed: 'Ukończone',
    noFeatureRequestsFound: 'Nie znaleziono propozycji',
    beTheFirstToSuggest: 'Bądź pierwszą osobą, która zaproponuje pomysł!',
    failedToLoadRequests: 'Nie udało się wczytać próśb',
    roadmap: 'Roadmap',
    noItemsInColumn: 'Brak elementów na tym etapie',

    newFeatureRequest: 'Zaproponuj funkcję',
    titleLabel: 'Tytuł *',
    titleHint: 'Co powinniśmy dodać lub ulepszyć?',
    detailsLabel: 'Szczegóły *',
    detailsHint: 'Opisz swój pomysł i dlaczego byłby przydatny...',
    yourNameOptional: 'Twoje imię (opcjonalnie)',
    yourNameHint: 'np. Alex',
    submitRequest: 'Wyślij prośbę',
    submitting: 'Wysyłanie...',
    featureRequestSubmitted: 'Prośba wysłana!',
    titleValidationMin3: 'Podaj tytuł o długości co najmniej 3 znaków.',
    detailsValidationMin5: 'Podaj szczegóły o długości co najmniej 5 znaków.',

    comments: 'Komentarze',
    writeAComment: 'Napisz komentarz...',
    send: 'Wyślij',
    posting: 'Publikowanie...',
    noCommentsYet: 'Brak komentarzy. Rozpocznij dyskusję!',
    vote: 'Głosuj',
    voted: 'Zagłosowano',

    sendFeedback: 'Wyślij opinię',
    submitFeedback: 'Prześlij opinię',
    feedbackSummaryHint: 'Krótkie podsumowanie...',
    feedbackDetailsHint: 'Co się stało i czego oczekiwałeś?',
    emailForRepliesOptional: 'E-mail do odpowiedzi (opcjonalnie)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Dziękujemy za opinię!',
    attachments: 'Załączniki',
    addAttachment: 'Dodaj załącznik',
    remove: 'Usuń',
    attachmentDefaultName: 'Załącznik',

    whatsNew: 'Co nowego',
    subscribeToUpdates: 'Bądź na bieżąco z nowościami',
    enterYourEmail: 'Wpisz swój e-mail',
    subscribe: 'Subskrybuj',
    subscribed: 'Zasubskrybowano!',
    gotIt: 'Rozumiem',
    version: 'Wersja',

    userProfile: 'Profil użytkownika',
    payingCustomer: 'Płacący klient',
    freeTier: 'Plan darmowy',
  );

  /// Built-in Norwegian (Bokmål) strings.
  static const no = CupThreadStrings(
    retry: 'Prøv igjen',
    cancel: 'Avbryt',
    close: 'Lukk',
    anonymous: 'Anonym',
    justNow: 'Akkurat nå',
    minutesAgoSuffix: ' min siden',
    hoursAgoSuffix: ' t siden',
    daysAgoSuffix: ' d siden',

    featureRequests: 'Funksjonsønsker',
    proposeFeature: 'Foreslå funksjon',
    proposeAnIdea: 'Foreslå en idé',
    searchFeatureRequests: 'Søk i ønsker...',
    all: 'Alle',
    underReview: 'Under vurdering',
    planned: 'Planlagt',
    inProgress: 'Pågår',
    completed: 'Fullført',
    noFeatureRequestsFound: 'Ingen ønsker funnet',
    beTheFirstToSuggest: 'Vær den første til å foreslå en idé!',
    failedToLoadRequests: 'Kunne ikke laste ønsker',
    roadmap: 'Veikart',
    noItemsInColumn: 'Ingen elementer på dette steget',

    newFeatureRequest: 'Foreslå en funksjon',
    titleLabel: 'Tittel *',
    titleHint: 'Hva bør vi legge til eller forbedre?',
    detailsLabel: 'Detaljer *',
    detailsHint: 'Beskriv idéen din og hvorfor den vil være nyttig...',
    yourNameOptional: 'Navnet ditt (valgfritt)',
    yourNameHint: 'f.eks. Alex',
    submitRequest: 'Send forespørsel',
    submitting: 'Sender...',
    featureRequestSubmitted: 'Ønsket er sendt!',
    titleValidationMin3: 'Oppgi en tittel med minst 3 tegn.',
    detailsValidationMin5: 'Oppgi detaljer med minst 5 tegn.',

    comments: 'Kommentarer',
    writeAComment: 'Skriv en kommentar...',
    send: 'Send',
    posting: 'Publiserer...',
    noCommentsYet: 'Ingen kommentarer ennå. Start samtalen!',
    vote: 'Stem',
    voted: 'Stemt',

    sendFeedback: 'Gi tilbakemelding',
    submitFeedback: 'Send tilbakemelding',
    feedbackSummaryHint: 'Kort sammendrag...',
    feedbackDetailsHint: 'Hva skjedde, og hva forventet du?',
    emailForRepliesOptional: 'E-post for svar (valgfritt)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Tilbakemelding sendt! Takk.',
    attachments: 'Vedlegg',
    addAttachment: 'Legg til vedlegg',
    remove: 'Fjern',
    attachmentDefaultName: 'Vedlegg',

    whatsNew: 'Nyheter',
    subscribeToUpdates: 'Hold deg oppdatert på nyheter',
    enterYourEmail: 'Skriv inn e-posten din',
    subscribe: 'Abonner',
    subscribed: 'Abonnert!',
    gotIt: 'Skjønner',
    version: 'Versjon',

    userProfile: 'Brukerprofil',
    payingCustomer: 'Betalende kunde',
    freeTier: 'Gratisplan',
  );

  /// Built-in Turkish strings.
  static const tr = CupThreadStrings(
    retry: 'Tekrar dene',
    cancel: 'İptal',
    close: 'Kapat',
    anonymous: 'Anonim',
    justNow: 'Az önce',
    minutesAgoSuffix: ' dk önce',
    hoursAgoSuffix: ' sa önce',
    daysAgoSuffix: ' gün önce',

    featureRequests: 'Özellik istekleri',
    proposeFeature: 'Özellik öner',
    proposeAnIdea: 'Fikir öner',
    searchFeatureRequests: 'İsteklerde ara...',
    all: 'Tümü',
    underReview: 'İnceleniyor',
    planned: 'Planlandı',
    inProgress: 'Devam ediyor',
    completed: 'Tamamlandı',
    noFeatureRequestsFound: 'Özellik isteği bulunamadı',
    beTheFirstToSuggest: 'Fikrini öneren ilk kişi ol!',
    failedToLoadRequests: 'İstekler yüklenemedi',
    roadmap: 'Yol haritası',
    noItemsInColumn: 'Bu aşamada öğe yok',

    newFeatureRequest: 'Özellik öner',
    titleLabel: 'Başlık *',
    titleHint: 'Ne eklemeli veya iyileştirmeliyiz?',
    detailsLabel: 'Ayrıntılar *',
    detailsHint: 'Fikrini ve neden faydalı olacağını açıkla...',
    yourNameOptional: 'Adın (isteğe bağlı)',
    yourNameHint: 'örn. Alex',
    submitRequest: 'İsteği gönder',
    submitting: 'Gönderiliyor...',
    featureRequestSubmitted: 'Özellik isteği gönderildi!',
    titleValidationMin3: 'En az 3 karakterlik bir başlık gir.',
    detailsValidationMin5: 'En az 5 karakterlik ayrıntı gir.',

    comments: 'Yorumlar',
    writeAComment: 'Yorum yaz...',
    send: 'Gönder',
    posting: 'Yayınlanıyor...',
    noCommentsYet: 'Henüz yorum yok. Sohbeti başlat!',
    vote: 'Oy ver',
    voted: 'Oy verildi',

    sendFeedback: 'Geri bildirim gönder',
    submitFeedback: 'Geri bildirimi gönder',
    feedbackSummaryHint: 'Kısa özet...',
    feedbackDetailsHint: 'Ne oldu ve ne bekliyordun?',
    emailForRepliesOptional: 'Yanıtlar için e-posta (isteğe bağlı)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Geri bildirim gönderildi! Teşekkürler.',
    attachments: 'Ekler',
    addAttachment: 'Ek ekle',
    remove: 'Kaldır',
    attachmentDefaultName: 'Ek',

    whatsNew: 'Yenilikler',
    subscribeToUpdates: 'Yeni sürümlerden haberdar ol',
    enterYourEmail: 'E-postanı gir',
    subscribe: 'Abone ol',
    subscribed: 'Abone olundu!',
    gotIt: 'Anladım',
    version: 'Sürüm',

    userProfile: 'Kullanıcı profili',
    payingCustomer: 'Ücretli müşteri',
    freeTier: 'Ücretsiz plan',
  );

  /// Built-in Vietnamese strings.
  static const vi = CupThreadStrings(
    retry: 'Thử lại',
    cancel: 'Hủy',
    close: 'Đóng',
    anonymous: 'Ẩn danh',
    justNow: 'Vừa xong',
    minutesAgoSuffix: ' phút trước',
    hoursAgoSuffix: ' giờ trước',
    daysAgoSuffix: ' ngày trước',

    featureRequests: 'Yêu cầu tính năng',
    proposeFeature: 'Đề xuất tính năng',
    proposeAnIdea: 'Đề xuất ý tưởng',
    searchFeatureRequests: 'Tìm kiếm yêu cầu...',
    all: 'Tất cả',
    underReview: 'Đang xem xét',
    planned: 'Đã lên kế hoạch',
    inProgress: 'Đang thực hiện',
    completed: 'Hoàn thành',
    noFeatureRequestsFound: 'Không tìm thấy yêu cầu nào',
    beTheFirstToSuggest: 'Hãy là người đầu tiên đề xuất ý tưởng!',
    failedToLoadRequests: 'Không tải được yêu cầu',
    roadmap: 'Lộ trình',
    noItemsInColumn: 'Không có mục nào trong giai đoạn này',

    newFeatureRequest: 'Đề xuất tính năng',
    titleLabel: 'Tiêu đề *',
    titleHint: 'Chúng tôi nên thêm hoặc cải thiện điều gì?',
    detailsLabel: 'Chi tiết *',
    detailsHint: 'Giải thích ý tưởng của bạn và vì sao nó hữu ích...',
    yourNameOptional: 'Tên của bạn (không bắt buộc)',
    yourNameHint: 'VD: Alex',
    submitRequest: 'Gửi yêu cầu',
    submitting: 'Đang gửi...',
    featureRequestSubmitted: 'Đã gửi yêu cầu tính năng!',
    titleValidationMin3: 'Vui lòng nhập tiêu đề ít nhất 3 ký tự.',
    detailsValidationMin5: 'Vui lòng nhập chi tiết ít nhất 5 ký tự.',

    comments: 'Bình luận',
    writeAComment: 'Viết bình luận...',
    send: 'Gửi',
    posting: 'Đang đăng...',
    noCommentsYet: 'Chưa có bình luận. Hãy bắt đầu thảo luận!',
    vote: 'Bình chọn',
    voted: 'Đã bình chọn',

    sendFeedback: 'Gửi phản hồi',
    submitFeedback: 'Gửi phản hồi',
    feedbackSummaryHint: 'Tóm tắt ngắn gọn...',
    feedbackDetailsHint: 'Đã xảy ra chuyện gì và bạn mong đợi điều gì?',
    emailForRepliesOptional: 'Email để phản hồi (không bắt buộc)',
    emailHint: 'alex@example.com',
    feedbackSent: 'Đã gửi phản hồi! Cảm ơn bạn.',
    attachments: 'Tệp đính kèm',
    addAttachment: 'Thêm tệp đính kèm',
    remove: 'Xóa',
    attachmentDefaultName: 'Tệp đính kèm',

    whatsNew: 'Có gì mới',
    subscribeToUpdates: 'Nhận tin về các bản phát hành mới',
    enterYourEmail: 'Nhập email của bạn',
    subscribe: 'Đăng ký',
    subscribed: 'Đã đăng ký!',
    gotIt: 'Đã hiểu',
    version: 'Phiên bản',

    userProfile: 'Hồ sơ người dùng',
    payingCustomer: 'Khách hàng trả phí',
    freeTier: 'Gói miễn phí',
  );

  /// Resolves the appropriate strings based on the given locale.
  static CupThreadStrings fromLocale(Locale? locale) {
    if (locale == null) return en;
    switch (locale.languageCode.toLowerCase()) {
      case 'zh':
        // Traditional Chinese for Hant script or TW/HK/MO regions.
        final script = locale.scriptCode?.toLowerCase();
        final region = locale.countryCode?.toLowerCase();
        if (script == 'hant' ||
            region == 'hant' ||
            region == 'tw' ||
            region == 'hk' ||
            region == 'mo') {
          return zhHant;
        }
        return zhHans;
      case 'ja':
        return ja;
      case 'fr':
        return fr;
      case 'es':
        return es;
      case 'de':
        return de;
      case 'it':
        return it;
      case 'pt':
        return pt;
      case 'ko':
        return ko;
      case 'pl':
        return pl;
      case 'no':
      case 'nb':
      case 'nn':
        return no;
      case 'tr':
        return tr;
      case 'vi':
        return vi;
      default:
        return en;
    }
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
