import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/theme/app_theme.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/navigation/main_scaffold.dart';
import 'package:accounting_system/presentation/navigation/app_router.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/l10n/locale_provider.dart';

class AccountingApp extends StatefulWidget {
  final AppDatabase db;
  final bool subscriptionExpired;

  const AccountingApp({super.key, required this.db, this.subscriptionExpired = false});

  @override
  State<AccountingApp> createState() => _AccountingAppState();
}

class _AccountingAppState extends State<AccountingApp> {
  final _localeProvider = LocaleProvider();
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = _localeProvider.locale;
    _localeProvider.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {
        _locale = _localeProvider.locale;
      });
    }
  }

  @override
  void dispose() {
    _localeProvider.removeListener(_onLocaleChanged);
    _localeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LocaleProviderScope(
      provider: _localeProvider,
      child: AppDatabaseProvider(
        db: widget.db,
        subscriptionExpired: widget.subscriptionExpired,
        child: MaterialApp(
          title: 'Accounting System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: _locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MainScaffold(),
          onGenerateRoute: AppRouter.generateRoute,
        ),
      ),
    );
  }
}
