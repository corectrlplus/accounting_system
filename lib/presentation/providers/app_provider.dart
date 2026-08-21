import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';

class AppDatabaseProvider extends InheritedWidget {
  final AppDatabase db;
  final bool subscriptionExpired;

  const AppDatabaseProvider({
    super.key,
    required this.db,
    this.subscriptionExpired = false,
    required super.child,
  });

  static AppDatabase of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppDatabaseProvider>();
    assert(provider != null, 'No AppDatabaseProvider found in context');
    return provider!.db;
  }

  static bool isExpired(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppDatabaseProvider>();
    return provider?.subscriptionExpired ?? false;
  }

  @override
  bool updateShouldNotify(AppDatabaseProvider oldWidget) =>
      subscriptionExpired != oldWidget.subscriptionExpired;
}
