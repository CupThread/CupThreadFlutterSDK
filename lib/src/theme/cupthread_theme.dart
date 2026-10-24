import 'package:flutter/material.dart';
import '../client/feedback_client.dart';
import '../client/user_token_store.dart';
import '../models/config.dart';
import 'cupthread_strings.dart';
import 'sdk_theme.dart';

export 'cupthread_strings.dart';
export 'sdk_theme.dart';

/// InheritedWidget providing CupThread theme colors, client, user token, and localized strings.
class CupThreadThemeScope extends InheritedWidget {
  final FeedbackClient client;
  final String userToken;
  final CupThreadColors colors;
  final SdkTheme theme;

  /// The host's explicit `theme:` override, or null when [theme] was
  /// resolved from remote config (or defaults to system). Scope-carrying
  /// modal routes forward this instead of [theme] so a sheet that captured
  /// the scope before config resolved can still apply the fetched theme.
  final SdkTheme? hostTheme;
  final PublicAppConfig? appConfig;
  final bool isConfigLoading;
  final Object? configError;
  final VoidCallback? retryConfig;
  final bool failClosed;
  final bool isAnonymous;
  final CupThreadStrings strings;
  final Locale? locale;

  const CupThreadThemeScope({
    super.key,
    required this.client,
    required this.userToken,
    required this.colors,
    required this.theme,
    this.hostTheme,
    this.appConfig,
    this.isConfigLoading = false,
    this.configError,
    this.retryConfig,
    this.failClosed = true,
    this.isAnonymous = true,
    required this.strings,
    this.locale,
    required super.child,
  });

  @override
  bool updateShouldNotify(CupThreadThemeScope oldWidget) {
    return client != oldWidget.client ||
        userToken != oldWidget.userToken ||
        colors != oldWidget.colors ||
        theme != oldWidget.theme ||
        hostTheme != oldWidget.hostTheme ||
        appConfig != oldWidget.appConfig ||
        isConfigLoading != oldWidget.isConfigLoading ||
        configError != oldWidget.configError ||
        failClosed != oldWidget.failClosed ||
        isAnonymous != oldWidget.isAnonymous ||
        strings != oldWidget.strings ||
        locale != oldWidget.locale;
  }
}

/// Root widget that wraps UI with CupThread appearance and localization settings.
class CupThreadTheme extends StatefulWidget {
  final FeedbackClient client;
  final String? userToken;
  final SdkTheme? theme;
  final Locale? locale;
  final CupThreadStrings? strings;
  final PublicAppConfig? config;
  final bool failClosed;

  /// Overrides anonymous-state detection for the wrapped session.
  ///
  /// When null (default), the session is treated as anonymous if and only if
  /// [userToken] is null. Scope-carrying modal routes pass the outer scope's
  /// value so sheets keep the host's authentication state even though a
  /// resolved token is always forwarded to them.
  final bool? isAnonymousOverride;

  final Widget child;

  const CupThreadTheme({
    super.key,
    required this.client,
    this.userToken,
    this.theme,
    this.locale,
    this.strings,
    this.config,
    this.failClosed = true,
    this.isAnonymousOverride,
    required this.child,
  });

  /// Accesses current CupThread theme colors.
  static CupThreadColors of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    if (scope != null) return scope.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupThreadColors.resolve(SdkTheme.system, isDarkMode: isDark);
  }

  /// Accesses current CupThread localized strings.
  static CupThreadStrings stringsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    if (scope != null) return scope.strings;
    final locale = Localizations.maybeLocaleOf(context);
    return CupThreadStrings.fromLocale(locale);
  }

  /// Accesses the current resolved [SdkTheme] (host override, remote config
  /// theme, or [SdkTheme.system] when no scope is present).
  static SdkTheme themeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    return scope?.theme ?? SdkTheme.system;
  }

  /// Accesses the current locale (host override, or the ambient MaterialApp
  /// locale when no scope is present).
  static Locale? localeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    return scope?.locale ?? Localizations.maybeLocaleOf(context);
  }

  /// Accesses current FeedbackClient instance.
  static FeedbackClient clientOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
        context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    assert(scope != null, 'No CupThreadTheme found in widget tree');
    return scope!.client;
  }

  /// Accesses current anonymous or authenticated user token.
  static String userTokenOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
        context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    return scope?.userToken ?? UserTokenStore.shared.token;
  }

  /// Whether current session is using an unauthenticated/anonymous token.
  static bool isAnonymous(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
        context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    return scope?.isAnonymous ?? true;
  }

  /// Accesses current public app configuration, if resolved.
  static PublicAppConfig? configOf(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>()
        : (context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
            context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>());
    return scope?.appConfig;
  }

  /// Accesses remote SdkFeatures flags from loaded config, or null if not yet resolved.
  static SdkFeatures? featuresOf(BuildContext context, {bool listen = true}) {
    return configOf(context, listen: listen)?.sdk.features;
  }

  /// Whether app configuration is currently being fetched.
  static bool isConfigLoading(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>()
        : (context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
            context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>());
    return scope?.isConfigLoading ?? false;
  }

  /// Returns configuration fetch error if loading failed.
  static Object? configErrorOf(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>()
        : (context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
            context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>());
    return scope?.configError;
  }

  /// Retries fetching app configuration after an error.
  static void retryConfig(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
        context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    scope?.retryConfig?.call();
  }

  /// Whether the SDK fails closed (disables features) when configuration fails to load.
  static bool failClosedOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
        context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    return scope?.failClosed ?? true;
  }

  /// Helper to check if a specific feature is enabled by remote configuration.
  ///
  /// Evaluates [featureSelector] against [SdkFeatures] if config is loaded.
  /// If config has not loaded yet or failed to load:
  /// - Returns false if failClosed is true (default).
  /// - Returns true if failClosed is false.
  static bool isFeatureEnabled(
    BuildContext context,
    bool Function(SdkFeatures features) featureSelector, {
    bool? failClosed,
    bool listen = true,
  }) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>()
        : (context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
            context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>());
    final effectiveFailClosed = failClosed ?? scope?.failClosed ?? true;

    if (scope == null) return !effectiveFailClosed;

    if (scope.appConfig != null) {
      return featureSelector(scope.appConfig!.sdk.features);
    }

    // Config is either still loading or errored
    return !effectiveFailClosed;
  }

  /// Re-installs the ambient CupThread scope around [child] so modal routes
  /// (bottom sheets, dialogs) present identical UI to the host application.
  ///
  /// Routes pushed on the Navigator are built outside the host subtree, so a
  /// bare [CupThreadTheme] inside them would re-resolve appearance and
  /// localization from the device, dropping host `theme:`, `strings:` and
  /// `locale:` overrides. Call this with the context that opens the route —
  /// before it is pushed — to capture the surrounding [CupThreadThemeScope]
  /// and forward every field (client, user token, resolved theme, strings,
  /// locale, app config, fail-closed policy, anonymous state) into the route.
  ///
  /// If the captured config has not resolved yet, the carried scope fetches it
  /// from the shared client, mirroring a standalone [CupThreadTheme]. When no
  /// scope is present, [child] is returned unchanged.
  static Widget carryScope(BuildContext context, {required Widget child}) {
    final scope = context.getInheritedWidgetOfExactType<CupThreadThemeScope>() ??
        context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    if (scope == null) return child;
    return CupThreadTheme(
      client: scope.client,
      userToken: scope.userToken,
      // Forward only the host's explicit override; when the captured scope
      // resolved its theme from remote config (or system), the carried scope
      // re-resolves so a config fetched after capture still applies.
      theme: scope.hostTheme,
      strings: scope.strings,
      locale: scope.locale,
      config: scope.appConfig,
      failClosed: scope.failClosed,
      isAnonymousOverride: scope.isAnonymous,
      child: child,
    );
  }

  @override
  State<CupThreadTheme> createState() => _CupThreadThemeState();
}

class _CupThreadThemeState extends State<CupThreadTheme> {
  PublicAppConfig? _appConfig;
  String? _resolvedToken;
  bool _isConfigLoading = true;
  Object? _configError;

  @override
  void initState() {
    super.initState();
    if (widget.config != null) {
      _appConfig = widget.config;
      _isConfigLoading = false;
    } else if (widget.client.cachedAppConfig != null) {
      _appConfig = widget.client.cachedAppConfig;
      _isConfigLoading = false;
    }
    _resolveToken();
    if (_appConfig == null) {
      _loadConfig();
    }
  }

  @override
  void didUpdateWidget(CupThreadTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userToken != widget.userToken) {
      if (widget.userToken == null) {
        // Switched back to anonymous: re-gate until the durable identity
        // has been restored from storage.
        setState(() => _resolvedToken = null);
      }
      _resolveToken();
    }
    if (widget.config != oldWidget.config) {
      setState(() {
        _appConfig = widget.config;
        _isConfigLoading = widget.config == null;
        _configError = null;
      });
      if (widget.config == null) {
        _loadConfig();
      }
    } else if (oldWidget.client != widget.client && widget.config == null) {
      _loadConfig();
    }
  }

  Future<void> _resolveToken() async {
    if (widget.userToken != null) {
      if (mounted) setState(() => _resolvedToken = widget.userToken);
      return;
    }
    final token = await UserTokenStore.shared.getToken();
    if (!mounted) return;
    // An explicit userToken provided while the storage read was in flight
    // always wins over the restored anonymous identity.
    if (widget.userToken != null) return;
    setState(() => _resolvedToken = token);
  }

  Future<void> _loadConfig() async {
    if (widget.config != null) {
      setState(() {
        _appConfig = widget.config;
        _isConfigLoading = false;
        _configError = null;
      });
      return;
    }
    setState(() {
      _isConfigLoading = true;
      _configError = null;
    });
    try {
      final config = await widget.client.fetchAppConfig(forceRefresh: true);
      if (mounted) {
        setState(() {
          _appConfig = config;
          _isConfigLoading = false;
          _configError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfigLoading = false;
          _configError = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = _resolvedToken;
    if (token == null) {
      // The durable anonymous identity is still being restored from storage.
      // Defer the child build so the first usable paint cannot capture an
      // ephemeral token (otherwise votes, own-request highlighting, and
      // changelog-seen state would be attributed to a throwaway identity).
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTheme = widget.theme ?? _appConfig?.sdk.theme ?? SdkTheme.system;
    final colors = CupThreadColors.resolve(effectiveTheme, isDarkMode: isDark);
    final effectiveLocale = widget.locale ?? Localizations.maybeLocaleOf(context);
    final effectiveStrings = widget.strings ?? CupThreadStrings.fromLocale(effectiveLocale);

    return CupThreadThemeScope(
      client: widget.client,
      userToken: token,
      colors: colors,
      theme: effectiveTheme,
      hostTheme: widget.theme,
      appConfig: _appConfig,
      isConfigLoading: _isConfigLoading,
      configError: _configError,
      retryConfig: _loadConfig,
      failClosed: widget.failClosed,
      isAnonymous: widget.isAnonymousOverride ?? widget.userToken == null,
      strings: effectiveStrings,
      locale: effectiveLocale,
      child: widget.child,
    );
  }
}
