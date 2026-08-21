import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/domain/license/license_service.dart';
import 'package:accounting_system/presentation/app.dart';
import 'package:accounting_system/presentation/screens/license/activation_screen.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

Future<SqfliteQueryExecutor> _createExecutor() async {
  return SqfliteQueryExecutor.inDatabaseFolder(
    path: 'accounting_system.db',
  );
}

const _localizationDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _supportedLocales = [
  Locale('ar'),
  Locale('en'),
  Locale('tr'),
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  runApp(const AppEntry());
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

enum AppLicenseState { checking, activated, expired, needsActivation }

class _AppEntryState extends State<AppEntry> {
  AppLicenseState _licenseState = AppLicenseState.checking;
  bool _dbReady = false;
  AppDatabase? _db;
  String? _dbError;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    AppLicenseState state = AppLicenseState.needsActivation;
    try {
      final hasLicense = await LicenseService.hasLicense();
      if (hasLicense) {
        final result = await LicenseService.verify();
        if (result.valid) {
          state = AppLicenseState.activated;
        } else if (result.isSubscriptionExpired) {
          state = AppLicenseState.expired;
        } else {
          state = AppLicenseState.needsActivation;
        }
      }
    } catch (_) {
      try {
        final hasLicense = await LicenseService.hasLicense();
        if (hasLicense) {
          final isExpired = await LicenseService.isExpired();
          state = isExpired ? AppLicenseState.expired : AppLicenseState.activated;
        }
      } catch (_) {
        state = AppLicenseState.needsActivation;
      }
    }
    if (!mounted) return;
    setState(() => _licenseState = state);
  }

  Future<void> _initDatabase() async {
    try {
      final executor = await _createExecutor();
      final db = AppDatabase(executor);
      await db.seedCompanyDefaults('default_company', 'device_1');
      if (!mounted) return;
      setState(() {
        _db = db;
        _dbReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _dbError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_licenseState == AppLicenseState.checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: _supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري التحقق من الترخيص...'),
              ],
            ),
          ),
        ),
      );
    }

    if (_licenseState == AppLicenseState.needsActivation) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: _supportedLocales,
        home: ActivationScreen(onActivated: () {
          setState(() => _licenseState = AppLicenseState.checking);
          _checkLicense();
        }),
      );
    }

    if (!_dbReady && _dbError == null) {
      _initDatabase();
    }

    final isExpired = _licenseState == AppLicenseState.expired;

    if (_dbError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: _supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('خطأ في تهيئة قاعدة البيانات'),
                const SizedBox(height: 8),
                Text(
                  _dbError!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _db = null;
                      _dbReady = false;
                      _dbError = null;
                    });
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_db == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: _supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تهيئة النظام...'),
              ],
            ),
          ),
        ),
      );
    }

    return AccountingApp(db: _db!, subscriptionExpired: isExpired);
  }
}
