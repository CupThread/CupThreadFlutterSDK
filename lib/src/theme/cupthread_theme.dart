import 'package:flutter/material.dart';
import '../client/feedback_client.dart';
import '../client/user_token_store.dart';
import '../models/config.dart';
import 'sdk_theme.dart';

/// InheritedWidget providing CupThread theme colors, client, and user token.
class CupThreadThemeScope extends InheritedWidget {
  final FeedbackClient client;
  final String userToken;
  final CupThreadColors colors;
  final SdkTheme theme;
  final PublicAppConfig? appConfig;

  const CupThreadThemeScope({
    super.key,
    required this.client,
    required this.userToken,
    required this.colors,
    required this.theme,
    this.appConfig,
    required super.child,
  });

  @override
  bool updateShouldNotify(CupThreadThemeScope oldWidget) {
    return client != oldWidget.client ||
        userToken != oldWidget.userToken ||
        colors != oldWidget.colors ||
        theme != oldWidget.theme ||
        appConfig != oldWidget.appConfig;
  }
}

/// Root widget that wraps UI with CupThread appearance settings.
class CupThreadTheme extends StatefulWidget {
  final FeedbackClient client;
  final String? userToken;
  final SdkTheme? theme;
  final Widget child;

  const CupThreadTheme({
    super.key,
    required this.client,
    this.userToken,
    this.theme,
    required this.child,
  });

  /// Accesses current CupThread theme colors.
  static CupThreadColors of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    if (scope != null) return scope.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupThreadColors.resolve(SdkTheme.system, isDarkMode: isDark);
  }

  /// Accesses current FeedbackClient instance.
  static FeedbackClient clientOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    assert(scope != null, 'No CupThreadTheme found in widget tree');
    return scope!.client;
  }

  /// Accesses current anonymous user token.
  static String userTokenOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CupThreadThemeScope>();
    return scope?.userToken ?? UserTokenStore.shared.token;
  }

  @override
  State<CupThreadTheme> createState() => _CupThreadThemeState();
}

class _CupThreadThemeState extends State<CupThreadTheme> {
  PublicAppConfig? _appConfig;
  String? _resolvedToken;

  @override
  void initState() {
    super.initState();
    _resolveToken();
    _loadConfig();
  }

  @override
  void didUpdateWidget(CupThreadTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userToken != widget.userToken) {
      _resolveToken();
    }
    if (oldWidget.client != widget.client) {
      _loadConfig();
    }
  }

  Future<void> _resolveToken() async {
    if (widget.userToken != null) {
      setState(() => _resolvedToken = widget.userToken);
    } else {
      final token = await UserTokenStore.shared.getToken();
      if (mounted) setState(() => _resolvedToken = token);
    }
  }

  Future<void> _loadConfig() async {
    try {
      final config = await widget.client.fetchAppConfig();
      if (mounted) setState(() => _appConfig = config);
    } catch (_) {
      // Non-fatal
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTheme = widget.theme ?? _appConfig?.sdk.theme ?? SdkTheme.system;
    final colors = CupThreadColors.resolve(effectiveTheme, isDarkMode: isDark);
    final token = _resolvedToken ?? widget.userToken ?? UserTokenStore.shared.token;

    return CupThreadThemeScope(
      client: widget.client,
      userToken: token,
      colors: colors,
      theme: effectiveTheme,
      appConfig: _appConfig,
      child: widget.child,
    );
  }
}
