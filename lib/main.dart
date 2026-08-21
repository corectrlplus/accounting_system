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

class _AppEntryState extends State<AppEntry> {
  bool _checking = true;
  bool _activated = false;
  Future<AppDatabase>? _dbFuture;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    bool activated = false;
    try {
      final hasLicense = await LicenseService.hasLicense();
      if (hasLicense) {
        final result = await LicenseService.verify();
        activated = result.valid;
      }
    } catch (_) {
      try {
        activated = await LicenseService.hasLicense();
      } catch (_) {
        activated = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _activated = activated;
      _checking = false;
    });
  }

  void _initDatabase() {
    if (_dbFuture == null) {
      _dbFuture = _initDatabaseImpl();
    }
  }

  Future<AppDatabase> _initDatabaseImpl() async {
    final executor = await _createExecutor();
    final db = AppDatabase(executor);
    await db.seedCompanyDefaults('default_company', 'device_1');
    return db;
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
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

    if (!_activated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: _supportedLocales,
        home: ActivationScreen(onActivated: () {
          setState(() => _activated = true);
        }),
      );
    }

    _initDatabase();

    return FutureBuilder<AppDatabase>(
      future: _dbFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
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
        if (snapshot.hasError) {
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
                    Text('خطأ في تهيئة قاعدة البيانات'),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _dbFuture = null;
                          _initDatabase();
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
        return AccountingApp(db: snapshot.data!);
      },
    );
  }
}
